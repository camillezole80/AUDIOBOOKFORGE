import Foundation

enum QwenEmotionTest: String, CaseIterable, Identifiable {
    case none
    case joy
    case sadness
    case anger
    case fear
    case tenderness
    case sinister
    case surprise
    case urgency
    case exhaustion
    case whisper

    var id: Self { self }

    var label: String {
        switch self {
        case .none: return "Aucune, identité seule"
        case .joy: return "Joie"
        case .sadness: return "Tristesse"
        case .anger: return "Colère contenue"
        case .fear: return "Peur"
        case .tenderness: return "Tendresse"
        case .sinister: return "Sinistre"
        case .surprise: return "Surprise"
        case .urgency: return "Urgence"
        case .exhaustion: return "Épuisement"
        case .whisper: return "Chuchotement"
        }
    }

    var instruction: String? {
        switch self {
        case .none: return nil
        case .joy:
            return "Speak with genuine joy, a smiling tone, lively energy and bright natural intonation"
        case .sadness:
            return "Speak with restrained sadness, subdued energy, a fragile tone and reflective pauses"
        case .anger:
            return "Speak with controlled anger, firm emphasis, tense breath and forceful but intelligible articulation"
        case .fear:
            return "Speak with mounting fear, unsteady breath, tense pacing and a vulnerable trembling tone"
        case .tenderness:
            return "Speak with tenderness, warmth, intimacy and gentle reassuring phrasing"
        case .sinister:
            return "Speak in a sinister, ominous and unsettling manner with deliberate pauses"
        case .surprise:
            return "Speak with sudden authentic surprise, widened intonation and a brief startled breath"
        case .urgency:
            return "Speak with urgent adrenaline, rapid controlled pacing, short breaths and sharp emphasis"
        case .exhaustion:
            return "Speak as if physically exhausted, weak and short of breath, with low energy and effortful pauses"
        case .whisper:
            return "Speak in a close, soft whisper with airy breath and intimate proximity while remaining intelligible"
        }
    }
}
