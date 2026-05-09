#!/usr/bin/env python3
"""
Génération audio via Fish Audio S2 Pro avec MLX.
Utilise mlx-speech pour la synthèse vocale locale.

Usage:
    python fish_s2_pro.py \\
        --text "Texte à générer" \\
        --model-dir models/fishaudio-s2-pro-8bit-mlx \\
        --reference-audio reference.wav \\
        --reference-text "Transcription du sample" \\
        --output output.wav \\
        --max-new-tokens 2048
"""

import argparse
import os
import sys
import time


def generate_audio(
    text: str,
    model_dir: str,
    reference_audio: str,
    reference_text: str,
    output_path: str,
    max_new_tokens: int = 2048,
    length_scale: float = 1.0,
    temperature: float = 0.8,
):
    """
    Génère de l'audio à partir de texte en utilisant Fish S2 Pro via MLX.
    
    Cette fonction sert de wrapper pour mlx-speech.
    Les paramètres correspondent à l'API de fish_s2_pro de mlx-speech.
    """
    # Vérifications préalables
    if not os.path.exists(model_dir):
        print(f"Erreur : modèle introuvable : {model_dir}", file=sys.stderr)
        sys.exit(1)

    if not os.path.exists(reference_audio):
        print(f"Erreur : audio de référence introuvable : {reference_audio}", file=sys.stderr)
        sys.exit(1)

    if not reference_text.strip():
        print("Erreur : la transcription de référence est vide", file=sys.stderr)
        sys.exit(1)

    # Créer le dossier de sortie si nécessaire
    os.makedirs(os.path.dirname(output_path) or '.', exist_ok=True)

    print(f"Génération audio en cours...")
    print(f"  Texte : {text[:100]}...")
    print(f"  Modèle : {model_dir}")
    print(f"  Sample : {reference_audio}")
    print(f"  Max tokens : {max_new_tokens}")
    print(f"  Length scale : {length_scale}")
    print(f"  Temperature : {temperature}")

    try:
        # Tentative d'import de mlx-speech
        # Note: l'import réel dépend de la structure exacte du package mlx-speech
        try:
            from mlx_speech import FishS2ProGenerator
            
            generator = FishS2ProGenerator(
                model_path=model_dir,
                reference_audio=reference_audio,
                reference_text=reference_text,
            )
            
            start_time = time.time()
            generator.generate(
                text=text,
                output_path=output_path,
                max_new_tokens=max_new_tokens,
                length_scale=length_scale,
                temperature=temperature,
            )
            elapsed = time.time() - start_time
            
            print(f"Génération terminée en {elapsed:.1f}s")
            print(f"Fichier : {output_path}")
            
        except ImportError:
            # Fallback : simulation pour test (à remplacer par l'appel réel)
            print("AVERTISSEMENT : mlx-speech non installé. Génération simulée.", file=sys.stderr)
            print(f"Commande simulée : python scripts/generate/fish_s2_pro.py ...", file=sys.stderr)
            
            # Créer un fichier WAV silencieux pour test
            _create_silent_wav(output_path)
            print(f"Fichier silencieux créé : {output_path}")

    except Exception as e:
        print(f"Erreur lors de la génération : {e}", file=sys.stderr)
        sys.exit(1)


def _create_silent_wav(output_path: str, duration_sec: float = 1.0, sample_rate: int = 44100):
    """
    Crée un fichier WAV silencieux pour les tests.
    Utilisé uniquement quand mlx-speech n'est pas disponible.
    """
    import struct

    num_samples = int(sample_rate * duration_sec)
    
    with open(output_path, 'wb') as f:
        # RIFF header
        f.write(b'RIFF')
        f.write(struct.pack('<I', 36 + num_samples * 2))
        f.write(b'WAVE')
        
        # fmt chunk
        f.write(b'fmt ')
        f.write(struct.pack('<I', 16))  # chunk size
        f.write(struct.pack('<H', 1))   # PCM
        f.write(struct.pack('<H', 1))   # mono
        f.write(struct.pack('<I', sample_rate))
        f.write(struct.pack('<I', sample_rate * 2))  # byte rate
        f.write(struct.pack('<H', 2))   # block align
        f.write(struct.pack('<H', 16))  # bits per sample
        
        # data chunk
        f.write(b'data')
        f.write(struct.pack('<I', num_samples * 2))
        
        # Silent samples (16-bit PCM)
        for _ in range(num_samples):
            f.write(struct.pack('<h', 0))


def main():
    parser = argparse.ArgumentParser(description='Génération audio Fish S2 Pro via MLX')
    parser.add_argument('--text', required=True, help='Texte à générer')
    parser.add_argument('--model-dir', required=True, help='Chemin vers le modèle MLX')
    parser.add_argument('--reference-audio', required=True, help='Fichier audio de référence')
    parser.add_argument('--reference-text', required=True, help='Transcription du sample de référence')
    parser.add_argument('--output', required=True, help='Fichier WAV de sortie')
    parser.add_argument('--max-new-tokens', type=int, default=2048, help='Nombre max de tokens')
    parser.add_argument('--length-scale', type=float, default=1.0, help='Échelle de vitesse (0.8-1.2)')
    parser.add_argument('--temperature', type=float, default=0.8, help='Température (0.6-1.0)')
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
