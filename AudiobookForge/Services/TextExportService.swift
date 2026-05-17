import Foundation
import AppKit

/// Service d'export du texte balisé en PDF ou TXT
class TextExportService {
    static let shared = TextExportService()
    
    private let logger = Logger.shared
    
    private init() {
        logger.info("TextExportService initialized")
    }
    
    /// Exporte le texte balisé d'un projet en TXT
    func exportToTXT(project: Project, outputPath: String) throws {
        logger.info("Exporting tagged text to TXT: \(outputPath)")
        
        var content = ""
        
        // En-tête
        content += "═══════════════════════════════════════════════════════════\n"
        content += "  \(project.metadata.title.isEmpty ? project.name : project.metadata.title)\n"
        if !project.metadata.author.isEmpty {
            content += "  par \(project.metadata.author)\n"
        }
        content += "═══════════════════════════════════════════════════════════\n\n"
        content += "Texte enrichi avec balises émotionnelles\n"
        content += "Généré par AudiobookForge v\(AppVersion.bundleVersion)\n"
        content += "Date : \(Date().formatted(date: .long, time: .shortened))\n\n"
        content += "═══════════════════════════════════════════════════════════\n\n"
        
        // Chapitres
        for chapter in project.chapters {
            content += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            content += "\(chapter.title)\n"
            content += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
            
            if let taggedText = chapter.taggedText {
                content += taggedText
            } else {
                content += chapter.rawText
                content += "\n\n[Note: Ce chapitre n'a pas encore été enrichi avec des balises émotionnelles]\n"
            }
            
            content += "\n\n"
        }
        
        // Légende des balises
        content += "\n═══════════════════════════════════════════════════════════\n"
        content += "LÉGENDE DES BALISES ÉMOTIONNELLES\n"
        content += "═══════════════════════════════════════════════════════════\n\n"
        content += "[whisper] - Chuchotement\n"
        content += "[excited] - Excitation\n"
        content += "[sad] - Tristesse\n"
        content += "[angry] - Colère\n"
        content += "[laughing] - Rire\n"
        content += "[chuckle] - Petit rire\n"
        content += "[emphasis] - Emphase\n"
        content += "[pause] - Pause\n"
        content += "[warm] - Chaleureux\n"
        content += "[tense] - Tendu\n"
        content += "[mysterious] - Mystérieux\n"
        content += "[professional broadcast tone] - Ton professionnel\n"
        content += "[clearing throat] - Raclement de gorge\n"
        content += "[inhale] - Inspiration\n"
        
        // Écrire le fichier
        try content.write(toFile: outputPath, atomically: true, encoding: .utf8)
        logger.info("✅ TXT export completed: \(outputPath)")
    }
    
    /// Exporte le texte balisé d'un projet en PDF
    func exportToPDF(project: Project, outputPath: String) throws {
        logger.info("Exporting tagged text to PDF: \(outputPath)")
        
        // Créer le contenu HTML pour la conversion en PDF
        var htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {
                    font-family: 'Georgia', serif;
                    font-size: 12pt;
                    line-height: 1.6;
                    margin: 40px;
                    color: #333;
                }
                h1 {
                    text-align: center;
                    font-size: 24pt;
                    margin-bottom: 10px;
                    border-bottom: 3px solid #333;
                    padding-bottom: 10px;
                }
                h2 {
                    font-size: 18pt;
                    margin-top: 30px;
                    margin-bottom: 15px;
                    border-bottom: 2px solid #666;
                    padding-bottom: 5px;
                }
                .metadata {
                    text-align: center;
                    font-style: italic;
                    margin-bottom: 30px;
                    color: #666;
                }
                .header {
                    text-align: center;
                    margin-bottom: 40px;
                    padding: 20px;
                    background-color: #f5f5f5;
                    border-radius: 5px;
                }
                .chapter {
                    margin-bottom: 40px;
                    page-break-after: always;
                }
                .tag {
                    color: #0066cc;
                    font-weight: bold;
                    font-style: italic;
                }
                .legend {
                    margin-top: 50px;
                    padding: 20px;
                    background-color: #f9f9f9;
                    border-left: 4px solid #0066cc;
                }
                .legend h3 {
                    margin-top: 0;
                }
                .legend-item {
                    margin: 5px 0;
                }
            </style>
        </head>
        <body>
        """
        
        // En-tête
        htmlContent += "<div class='header'>"
        htmlContent += "<h1>\(escapeHTML(project.metadata.title.isEmpty ? project.name : project.metadata.title))</h1>"
        if !project.metadata.author.isEmpty {
            htmlContent += "<div class='metadata'>par \(escapeHTML(project.metadata.author))</div>"
        }
        htmlContent += "<div class='metadata'>Texte enrichi avec balises émotionnelles</div>"
        htmlContent += "<div class='metadata'>Généré par AudiobookForge v\(AppVersion.bundleVersion)</div>"
        htmlContent += "<div class='metadata'>\(Date().formatted(date: .long, time: .shortened))</div>"
        htmlContent += "</div>"
        
        // Chapitres
        for chapter in project.chapters {
            htmlContent += "<div class='chapter'>"
            htmlContent += "<h2>\(escapeHTML(chapter.title))</h2>"
            
            let text = chapter.taggedText ?? chapter.rawText
            let formattedText = formatTextWithTags(text)
            htmlContent += "<p>\(formattedText)</p>"
            
            if chapter.taggedText == nil {
                htmlContent += "<p><em>[Note: Ce chapitre n'a pas encore été enrichi avec des balises émotionnelles]</em></p>"
            }
            
            htmlContent += "</div>"
        }
        
        // Légende
        htmlContent += """
        <div class='legend'>
            <h3>Légende des balises émotionnelles</h3>
            <div class='legend-item'><span class='tag'>[whisper]</span> - Chuchotement</div>
            <div class='legend-item'><span class='tag'>[excited]</span> - Excitation</div>
            <div class='legend-item'><span class='tag'>[sad]</span> - Tristesse</div>
            <div class='legend-item'><span class='tag'>[angry]</span> - Colère</div>
            <div class='legend-item'><span class='tag'>[laughing]</span> - Rire</div>
            <div class='legend-item'><span class='tag'>[chuckle]</span> - Petit rire</div>
            <div class='legend-item'><span class='tag'>[emphasis]</span> - Emphase</div>
            <div class='legend-item'><span class='tag'>[pause]</span> - Pause</div>
            <div class='legend-item'><span class='tag'>[warm]</span> - Chaleureux</div>
            <div class='legend-item'><span class='tag'>[tense]</span> - Tendu</div>
            <div class='legend-item'><span class='tag'>[mysterious]</span> - Mystérieux</div>
            <div class='legend-item'><span class='tag'>[professional broadcast tone]</span> - Ton professionnel</div>
            <div class='legend-item'><span class='tag'>[clearing throat]</span> - Raclement de gorge</div>
            <div class='legend-item'><span class='tag'>[inhale]</span> - Inspiration</div>
        </div>
        """
        
        htmlContent += "</body></html>"
        
        // Convertir HTML en PDF
        try convertHTMLToPDF(html: htmlContent, outputPath: outputPath)
        logger.info("✅ PDF export completed: \(outputPath)")
    }
    
    // MARK: - Helpers
    
    private func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    private func formatTextWithTags(_ text: String) -> String {
        var formatted = escapeHTML(text)
        
        // Mettre en évidence les balises émotionnelles
        let tagPattern = "\\[([^\\]]+)\\]"
        if let regex = try? NSRegularExpression(pattern: tagPattern, options: []) {
            let nsString = formatted as NSString
            let matches = regex.matches(in: formatted, options: [], range: NSRange(location: 0, length: nsString.length))
            
            // Remplacer en ordre inverse pour ne pas décaler les indices
            for match in matches.reversed() {
                let range = match.range
                let tag = nsString.substring(with: range)
                let replacement = "<span class='tag'>\(tag)</span>"
                formatted = (formatted as NSString).replacingCharacters(in: range, with: replacement)
            }
        }
        
        // Convertir les sauts de ligne en <br>
        formatted = formatted.replacingOccurrences(of: "\n", with: "<br>")
        
        return formatted
    }
    
    private func convertHTMLToPDF(html: String, outputPath: String) throws {
        // Utiliser NSAttributedString pour créer le PDF
        guard let htmlData = html.data(using: .utf8) else {
            throw TextExportError.pdfConversionFailed
        }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        guard let attributedString = try? NSAttributedString(data: htmlData, options: options, documentAttributes: nil) else {
            throw TextExportError.pdfConversionFailed
        }
        
        // Créer le PDF
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = NSSize(width: 595, height: 842) // A4
        printInfo.topMargin = 40
        printInfo.bottomMargin = 40
        printInfo.leftMargin = 40
        printInfo.rightMargin = 40
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 515, height: 762))
        textView.textStorage?.setAttributedString(attributedString)
        
        let printOperation = NSPrintOperation(view: textView, printInfo: printInfo)
        printOperation.showsPrintPanel = false
        printOperation.showsProgressPanel = false
        
        // Sauvegarder en PDF
        let pdfData = textView.dataWithPDF(inside: textView.bounds)
        try pdfData.write(to: URL(fileURLWithPath: outputPath))
    }
}

// MARK: - Errors

enum TextExportError: Error, LocalizedError {
    case exportFailed(String)
    case pdfConversionFailed
    
    var errorDescription: String? {
        switch self {
        case .exportFailed(let message):
            return "Échec de l'export : \(message)"
        case .pdfConversionFailed:
            return "Échec de la conversion en PDF"
        }
    }
}

// Import WebKit pour la conversion PDF
import WebKit
