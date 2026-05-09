#!/usr/bin/env python3
"""
Extraction de texte depuis un fichier EPUB.
Utilise ebooklib pour parser le fichier et extraire le texte structuré par chapitres.
"""

import argparse
import json
import os
import sys
from pathlib import Path

try:
    import ebooklib
    from ebooklib import epub
    from bs4 import BeautifulSoup
except ImportError:
    print("Erreur : ebooklib requis. Installez avec : pip install ebooklib beautifulsoup4")
    sys.exit(1)


def extract_epub(filepath: str, output_dir: str) -> None:
    """
    Extrait le texte d'un fichier EPUB.
    
    Args:
        filepath: Chemin vers le fichier EPUB
        output_dir: Dossier de sortie pour les fichiers JSON
    """
    book = epub.read_epub(filepath)

    # Métadonnées
    title = book.get_metadata('DC', 'title')
    creator = book.get_metadata('DC', 'creator')

    metadata = {
        'title': title[0][0] if title else '',
        'author': creator[0][0] if creator else ''
    }

    # Sauvegarder les métadonnées
    with open(os.path.join(output_dir, 'metadata.json'), 'w', encoding='utf-8') as f:
        json.dump(metadata, f, ensure_ascii=False, indent=2)

    # Extraction de la couverture
    for item in book.get_items():
        if item.get_type() == ebooklib.ITEM_COVER:
            cover_path = os.path.join(output_dir, 'cover.jpg')
            with open(cover_path, 'wb') as f:
                f.write(item.get_content())
            break
        elif item.get_type() == ebooklib.ITEM_IMAGE and 'cover' in item.get_name().lower():
            cover_path = os.path.join(output_dir, 'cover.jpg')
            with open(cover_path, 'wb') as f:
                f.write(item.get_content())
            break

    # Extraction des chapitres
    chapters = []
    chapter_index = 0

    for item in book.get_items():
        if item.get_type() == ebooklib.ITEM_DOCUMENT:
            content = item.get_content()
            soup = BeautifulSoup(content, 'html.parser')

            # Essayer de trouver le titre du chapitre
            title_tag = soup.find(['h1', 'h2', 'h3', 'title'])
            chapter_title = title_tag.get_text(strip=True) if title_tag else f'Chapitre {chapter_index + 1}'

            # Extraire tout le texte
            text_parts = []
            for element in soup.find_all(['p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'div']):
                text = element.get_text(strip=True)
                if text:
                    text_parts.append(text)

            full_text = '\n\n'.join(text_parts)

            if full_text.strip():
                chapters.append({
                    'title': chapter_title,
                    'text': full_text
                })
                chapter_index += 1

    # Sauvegarder les chapitres
    with open(os.path.join(output_dir, 'chapters.json'), 'w', encoding='utf-8') as f:
        json.dump(chapters, f, ensure_ascii=False, indent=2)

    print(f"Extraction terminée : {len(chapters)} chapitres extraits")
    print(f"Métadonnées : {metadata['title']} par {metadata['author']}")


def main():
    parser = argparse.ArgumentParser(description='Extraction de texte depuis EPUB')
    parser.add_argument('--input', required=True, help='Chemin vers le fichier EPUB')
    parser.add_argument('--output', required=True, help='Dossier de sortie')
    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"Erreur : fichier introuvable : {args.input}")
        sys.exit(1)

    os.makedirs(args.output, exist_ok=True)
    extract_epub(args.input, args.output)


if __name__ == '__main__':
    main()
