#!/usr/bin/env python3
"""
Génération audio via Fish Audio S2 Pro avec MLX (mlx-speech).

Deux modes :
- One-shot (legacy)  : charge le modèle, génère un fichier, quitte.
- Daemon (`--daemon`) : charge le modèle UNE FOIS puis lit des requêtes JSON
  ligne-par-ligne sur stdin. Évite le rechargement du modèle (~17 Go en RAM) à
  chaque chunk — le goulot d'étranglement du pipeline avant ce mode.

Protocole daemon (chaque ligne = un JSON unique) :

    stdin <-  {"id":"42","command":"generate","text":"…","reference_audio":"…",
               "reference_text":"…","output":"/path/out.wav",
               "max_new_tokens":2048,"temperature":0.8,"length_scale":1.0}
    stdout -> {"type":"ready","model":"fish-s2-pro"}                           (au démarrage)
    stdout -> {"type":"progress","id":"42","status":"generating"}              (optionnel)
    stdout -> {"type":"result","id":"42","status":"ok","output":"/path/out.wav"}
    stdout -> {"type":"result","id":"42","status":"error","message":"…"}

    stdin <-  {"id":"99","command":"shutdown"}
    stdout -> {"type":"result","id":"99","status":"ok"}
    EOF (le process quitte)
"""

import argparse
import json
import os
import sys
import time
import traceback

import numpy as np
import soundfile as sf


def _emit(payload: dict) -> None:
    """Émet un JSON sur stdout, flush immédiat (sinon Swift attend indéfiniment)."""
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()


def _load_model(model_dir: str | None):
    """Charge le modèle MLX. Retourne l'objet model prêt à .generate(...)."""
    from mlx_speech import tts
    model_id = model_dir or "fish-s2-pro"
    start = time.time()
    model = tts.load(model_id)
    elapsed = time.time() - start
    return model, model_id, elapsed


def _clear_metal_cache():
    """
    Libère les buffers Metal résiduels entre deux générations.
    Sans ça, en mode daemon, les caches s'accumulent et l'allocation suivante
    finit par dépasser la limite hardware de Metal (`metal::malloc` Attempting
    to allocate >14 Go) → crash du process Python.
    """
    try:
        import mlx.core as mx
        # clear_cache() existe sur MLX récent ; gc.collect() pour les références Python
        if hasattr(mx, "metal") and hasattr(mx.metal, "clear_cache"):
            mx.metal.clear_cache()
        elif hasattr(mx, "clear_cache"):
            mx.clear_cache()
    except Exception:
        pass
    import gc
    gc.collect()


def _generate_one(model, req: dict) -> None:
    """Génère un WAV à partir d'une requête. Lève sur erreur."""
    text = req["text"]
    reference_audio = req["reference_audio"]
    reference_text = req["reference_text"]
    output_path = req["output"]
    max_new_tokens = int(req.get("max_new_tokens", 2048))
    length_scale = float(req.get("length_scale", 1.0))
    temperature = float(req.get("temperature", 0.8))

    if not os.path.exists(reference_audio):
        raise FileNotFoundError(f"audio de référence introuvable : {reference_audio}")
    if not reference_text.strip():
        raise ValueError("la transcription de référence est vide")
    if not text.strip():
        raise ValueError("le texte à générer est vide")

    os.makedirs(os.path.dirname(output_path) or '.', exist_ok=True)

    output = model.generate(
        text=text,
        reference_audio=reference_audio,
        reference_text=reference_text,
        max_new_tokens=max_new_tokens,
        length_scale=length_scale,
        temperature=temperature,
    )

    waveform = np.array(output.waveform)
    sample_rate = output.sample_rate
    sf.write(output_path, waveform, samplerate=sample_rate, subtype='PCM_16')


def run_daemon(model_dir: str | None) -> int:
    """
    Boucle daemon : charge le modèle, lit du JSON sur stdin, génère, répond sur
    stdout, jusqu'à `shutdown` ou EOF.
    """
    try:
        model, model_id, load_seconds = _load_model(model_dir)
    except Exception as e:
        _emit({
            "type": "fatal",
            "message": f"échec du chargement du modèle : {e}",
            "traceback": traceback.format_exc(),
        })
        return 1

    _emit({"type": "ready", "model": model_id, "load_seconds": round(load_seconds, 2)})

    for raw_line in sys.stdin:
        line = raw_line.strip()
        if not line:
            continue

        try:
            req = json.loads(line)
        except json.JSONDecodeError as e:
            _emit({"type": "error", "message": f"JSON invalide : {e}"})
            continue

        req_id = str(req.get("id", ""))
        command = req.get("command", "generate")

        if command == "shutdown":
            _emit({"type": "result", "id": req_id, "status": "ok"})
            return 0

        if command != "generate":
            _emit({
                "type": "result", "id": req_id, "status": "error",
                "message": f"commande inconnue : {command}",
            })
            continue

        try:
            start = time.time()
            _generate_one(model, req)
            elapsed = time.time() - start
            _emit({
                "type": "result", "id": req_id, "status": "ok",
                "output": req["output"],
                "generation_seconds": round(elapsed, 2),
            })
        except Exception as e:
            _emit({
                "type": "result", "id": req_id, "status": "error",
                "message": str(e),
                "traceback": traceback.format_exc(),
            })
        finally:
            # Libère les buffers Metal du chunk précédent — sinon on dépasse
            # la limite par-buffer de Metal au bout de quelques chunks.
            _clear_metal_cache()

    # EOF sur stdin = arrêt propre
    return 0


def run_oneshot(args) -> int:
    """Mode legacy compatibilité — un seul chunk, puis quitte."""
    try:
        model, model_id, load_seconds = _load_model(args.model_dir)
    except ImportError as e:
        print(f"Erreur : mlx-speech non installé ({e})", file=sys.stderr)
        print("Installez-le avec : pip install mlx-speech", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Erreur lors du chargement du modèle : {e}", file=sys.stderr)
        traceback.print_exc(file=sys.stderr)
        return 1

    print(f"Modèle {model_id} chargé en {load_seconds:.1f}s")

    try:
        req = {
            "text": args.text,
            "reference_audio": args.reference_audio,
            "reference_text": args.reference_text,
            "output": args.output,
            "max_new_tokens": args.max_new_tokens,
            "length_scale": args.length_scale,
            "temperature": args.temperature,
        }
        start = time.time()
        _generate_one(model, req)
        elapsed = time.time() - start
        print(f"Fichier {args.output} généré en {elapsed:.1f}s")
        return 0
    except Exception as e:
        print(f"Erreur lors de la génération : {e}", file=sys.stderr)
        traceback.print_exc(file=sys.stderr)
        return 1


def main():
    parser = argparse.ArgumentParser(
        description='Génération audio Fish S2 Pro via MLX (mlx-speech)'
    )
    parser.add_argument('--daemon', action='store_true',
                        help='Mode daemon : modèle chargé une fois, requêtes JSON sur stdin')
    parser.add_argument('--model-dir', default=None,
                        help='Chemin local ou repo HF du modèle (défaut: appautomaton/fishaudio-s2-pro-8bit-mlx)')

    # Arguments one-shot (ignorés en mode daemon)
    parser.add_argument('--text', help='Texte à générer (one-shot)')
    parser.add_argument('--reference-audio', help='Fichier audio de référence (one-shot)')
    parser.add_argument('--reference-text', help='Transcription du sample (one-shot)')
    parser.add_argument('--output', help='Fichier WAV de sortie (one-shot)')
    parser.add_argument('--max-new-tokens', type=int, default=2048)
    parser.add_argument('--length-scale', type=float, default=1.0)
    parser.add_argument('--temperature', type=float, default=0.8)

    args = parser.parse_args()

    if args.daemon:
        sys.exit(run_daemon(args.model_dir))

    # Validation one-shot
    missing = [name for name in ("text", "reference_audio", "reference_text", "output")
               if getattr(args, name) is None]
    if missing:
        parser.error(f"arguments manquants en mode one-shot : {', '.join('--' + m.replace('_', '-') for m in missing)}")

    sys.exit(run_oneshot(args))


if __name__ == '__main__':
    main()
