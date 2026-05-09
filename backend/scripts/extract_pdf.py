#!/usr/bin/env python3
"""
Extraction de texte depuis un fichier PDF.
Utilise PyMuPDF (fitz) pour extraire le texte avec détection des titres par taille de police.
"""

import argparse
import json
import os
import sys

try:
    import fitz  # PyMuPDF
except ImportError:
    print("Erreur : PyMuPDF requis. Installez avec : pip install pymupdf")
    sys.exit(1)


def extract_pdf(filepath: str, output_dir: str) -> None:
    """
    Extrait le texte d'un fichier PDF avec détection de chapitres.
    
    Args:
        filepath: Chemin vers le fichier PDF
        output_dir: Dossier de sortie pour les fichiers JSON
    """
    doc = fitz.open(filepath)

    # Métadonnées
    metadata = {
        'title': doc.metadata.get('title', ''),
        'author': doc.metadata.get('author', '')
    }

    with open(os.path.join(output_dir, 'metadata.json'), 'w', encoding='utf-8') as f:
        json.dump(metadata, f, ensure_ascii=False, indent=2)

    # Extraction du texte par page avec détection des titres
    chapters = []
    current_chapter = None
    current_text = []
    chapter_index = 0

    # Calculer un seuil de titre adaptatif basé sur la taille de police médiane
    all_font_sizes = []
    for page_num in range(min(len(doc), 10)):  # Échantillonner les 10 premières pages
        page = doc[page_num]
        blocks = page.get_text("dict")["blocks"]
        for block in blocks:
            if block["type"] != 0:
                continue
            for line in block["lines"]:
                for span in line["spans"]:
                    all_font_sizes.append(span["size"])

    if all_font_sizes:
        sorted_sizes = sorted(all_font_sizes)
        median_size = sorted_sizes[len(sorted_sizes) // 2]
        # Un titre est généralement 2pt plus grand que le corps de texte
        TITLE_SIZE_THRESHOLD = median_size + 2.0
    else:
        TITLE_SIZE_THRESHOLD = 14.0  # Fallback

    for page_num in range(len(doc)):
        page = doc[page_num]
        blocks = page.get_text("dict")["blocks"]

        for block in blocks:
            if block["type"] != 0:  # 0 = texte
                continue

            for line in block["lines"]:
                text = ""
                max_font_size = 0

                for span in line["spans"]:
                    text += span["text"]
                    max_font_size = max(max_font_size, span["size"])

                text = text.strip()
                if not text:
                    continue

                # Détection de titre par taille de police (adaptative)
                if max_font_size >= TITLE_SIZE_THRESHOLD and len(text) < 200:
                    # Sauvegarder le chapitre précédent
                    if current_chapter is not None and current_text:
                        chapters.append({
                            'title': current_chapter,
                            'text': '\n\n'.join(current_text)
                        })
                        chapter_index += 1

                    current_chapter = text
                    current_text = []
                else:
                    # Vérifier si c'est un numéro de page
                    if text.isdigit() and len(text) <= 4:
                        continue
                    current_text.append(text)

    # Dernier chapitre
    if current_chapter is not None and current_text:
        chapters.append({
            'title': current_chapter,
            'text': '\n\n'.join(current_text)
        })

    # Si aucun chapitre détecté, tout mettre dans un seul chapitre
    if not chapters:
        all_text = []
        for page_num in range(len(doc)):
            page = doc[page_num]
            text = page.get_text()
            if text.strip():
                all_text.append(text.strip())

        chapters.append({
            'title': 'Document',
            'text': '\n\n'.join(all_text)
        })

    with open(os.path.join(output_dir, 'chapters.json'), 'w', encoding='utf-8') as f:
        json.dump(chapters, f, ensure_ascii=False, indent=2)

    print(f"Extraction terminée : {len(chapters)} chapitres extraits")
    print(f"Métadonnées : {metadata['title']} par {metadata['author']}")

    doc.close()


def main():
    parser = argparse.ArgumentParser(description='Extraction de texte depuis PDF')
    parser.add_argument('--input', required=True, help='Chemin vers le fichier PDF')
    parser.add_argument('--output', required=True, help='Dossier de sortie')
    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"Erreur : fichier introuvable : {args.input}")
        sys.exit(1)

    os.makedirs(args.output, exist_ok=True)
    extract_pdf(args.input, args.output)


if __name__ == '__main__':
    main()
