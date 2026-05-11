#!/usr/bin/env python3
"""
Génération audio via Fish Audio S2 Pro avec MLX (mlx-speech).

Utilise la vraie API mlx_speech.tts pour la synthèse vocale locale
avec clonage vocal et balises émotionnelles.

Usage:
    python fish_s2_pro.py \\
        --text "Texte à générer avec [warm] émotions" \\
        --reference-audio reference.wav \\
        --reference-text "Transcription exacte du sample" \\
        --output output.wav \\
        --max-new-tokens 2048 \\
        --temperature 0.8
"""

import argparse
import os
import sys
import time

import numpy as np
import soundfile as sf


def generate_audio(
    text: str,
    reference_audio: str,
    reference_text: str,
    output_path: str,
    model_dir: str | None = None,
    max_new_tokens: int = 2048,
    length_scale: float = 1.0,
    temperature: float = 0.8,
):
    """
    Génère de l'audio à partir de texte via Fish S2 Pro avec MLX.

    Utilise l'API mlx_speech.tts avec le modèle fish-s2-pro.
    Supporte les balises émotionnelles : [whisper], [sad], [excited], etc.

    Args:
        text: Texte à générer (peut contenir des balises émotionnelles)
        reference_audio: Chemin vers l'audio de référence (clonage vocal)
        reference_text: Transcription exacte du sample de référence
        output_path: Chemin WAV de sortie
        model_dir: Optionnel, chemin local ou repo HF du modèle
        max_new_tokens: Nombre max de tokens à générer
        length_scale: Échelle de vitesse (0.8 = plus rapide, 1.2 = plus lent)
        temperature: Température pour l'échantillonnage (0.6-1.0)
    """
    # Vérifications préalables
    if not os.path.exists(reference_audio):
        print(f"Erreur : audio de référence introuvable : {reference_audio}", file=sys.stderr)
        sys.exit(1)

    if not reference_text.strip():
        print("Erreur : la transcription de référence est vide", file=sys.stderr)
        sys.exit(1)

    if not text.strip():
        print("Erreur : le texte à générer est vide", file=sys.stderr)
        sys.exit(1)

    os.makedirs(os.path.dirname(output_path) or '.', exist_ok=True)

    print(f"Génération audio via mlx-speech fish-s2-pro...")
    print(f"  Texte : {text[:120]}...")
    print(f"  Sample : {reference_audio}")
    print(f"  Transcription : {reference_text[:80]}...")
    print(f"  Max tokens : {max_new_tokens}")
    print(f"  Length scale : {length_scale}")
    print(f"  Temperature : {temperature}")

    try:
        from mlx_speech import tts

        # Utiliser le nom de modèle mlx-speech (pas le repo HF)
        model_id = model_dir or "fish-s2-pro"

        print(f"  Chargement du modèle : {model_id}")
        start_load = time.time()
        model = tts.load(model_id)
        elapsed_load = time.time() - start_load
        print(f"  Modèle chargé en {elapsed_load:.1f}s")

        # Génération
        print("  Génération audio...")
        start_gen = time.time()

        output: tts.TTSOutput = model.generate(
            text=text,
            reference_audio=reference_audio,
            reference_text=reference_text,
            max_new_tokens=max_new_tokens,
            length_scale=length_scale,
            temperature=temperature,
        )

        elapsed_gen = time.time() - start_gen

        # Conversion mx.array → numpy → WAV
        waveform = np.array(output.waveform)
        sample_rate = output.sample_rate

        print(f"  Génération terminée en {elapsed_gen:.1f}s")
        print(f"  Waveform : {waveform.shape}, sample_rate: {sample_rate}Hz")
        print(f"  Durée estimée : {waveform.shape[-1] / sample_rate:.1f}s")

        # Sauvegarder en WAV 16-bit PCM
        sf.write(output_path, waveform, samplerate=sample_rate, subtype='PCM_16')
        print(f"  Fichier : {output_path}")

    except ImportError as e:
        print(f"Erreur : mlx-speech non installé ({e})", file=sys.stderr)
        print("Installez-le avec : pip install mlx-speech", file=sys.stderr)
        sys.exit(1)

    except Exception as e:
        print(f"Erreur lors de la génération : {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description='Génération audio Fish S2 Pro via MLX (mlx-speech)'
    )
    parser.add_argument('--text', required=True,
                        help='Texte à générer (avec balises optionnelles)')
    parser.add_argument('--model-dir', default=None,
                        help='Chemin local ou repo HF du modèle (défaut: appautomaton/fishaudio-s2-pro-8bit-mlx)')
    parser.add_argument('--reference-audio', required=True,
                        help='Fichier audio de référence pour le clonage vocal')
    parser.add_argument('--reference-text', required=True,
                        help='Transcription exacte du sample de référence')
    parser.add_argument('--output', required=True,
                        help='Fichier WAV de sortie')
    parser.add_argument('--max-new-tokens', type=int, default=2048,
                        help='Nombre max de tokens')
    parser.add_argument('--length-scale', type=float, default=1.0,
                        help='Échelle de vitesse (0.8-1.2)')
    parser.add_argument('--temperature', type=float, default=0.8,
                        help='Température (0.6-1.0)')

    args = parser.parse_args()

    generate_audio(
        text=args.text,
        model_dir=args.model_dir,
        reference_audio=args.reference_audio,
        reference_text=args.reference_text,
        output_path=args.output,
        max_new_tokens=args.max_new_tokens,
        length_scale=args.length_scale,
        temperature=args.temperature,
    )


if __name__ == '__main__':
    main()
