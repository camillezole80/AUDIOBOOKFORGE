import Foundation

enum VoiceDesignGender: String, CaseIterable, Identifiable {
    case masculine
    case feminine
    case neutral

    var id: Self { self }

    var label: String {
        switch self {
        case .masculine: return "Masculine"
        case .feminine: return "Féminine"
        case .neutral: return "Neutre / androgyne"
        }
    }

    var prompt: String {
        switch self {
        case .masculine: return "male voice"
        case .feminine: return "female voice"
        case .neutral: return "gender-neutral and androgynous voice"
        }
    }
}

enum VoiceDesignAge: String, CaseIterable, Identifiable {
    case child
    case teenager
    case youngAdult
    case adult
    case mature
    case elderly
    case veryElderly

    var id: Self { self }

    var label: String {
        switch self {
        case .child: return "Enfant"
        case .teenager: return "Adolescent"
        case .youngAdult: return "Jeune adulte"
        case .adult: return "Adulte"
        case .mature: return "Mature (50-65 ans)"
        case .elderly: return "Âgée (70-80 ans)"
        case .veryElderly: return "Très âgée (85-95 ans)"
        }
    }

    var prompt: String {
        switch self {
        case .child: return "a child around 9 years old, light and youthful"
        case .teenager: return "a teenager around 16 years old, youthful and developing"
        case .youngAdult: return "a young adult around 25 years old"
        case .adult: return "an adult around 40 years old"
        case .mature: return "a mature person around 60 years old"
        case .elderly:
            return "an elderly person around 78 years old, with audible age and reduced vocal energy"
        case .veryElderly:
            return "a very elderly person around 90 years old, frail, breath-limited, with audible vocal aging and an unstable voice"
        }
    }
}

enum VoiceDesignQuality: String, CaseIterable, Identifiable, Hashable {
    case deep
    case lowPitched
    case highPitched
    case raspy
    case hoarse
    case breathy
    case smoky
    case gravelly
    case tremulous
    case thin
    case resonant
    case warm
    case bright
    case nasal
    case sharp
    case soft
    case powerful
    case fragile
    case natural

    var id: Self { self }
    var sortOrder: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    var label: String {
        switch self {
        case .deep: return "Profonde"
        case .lowPitched: return "Grave"
        case .highPitched: return "Aiguë"
        case .raspy: return "Râpeuse"
        case .hoarse: return "Enrouée"
        case .breathy: return "Soufflée"
        case .smoky: return "Fumée"
        case .gravelly: return "Rocailleuse"
        case .tremulous: return "Tremblante"
        case .thin: return "Fine"
        case .resonant: return "Résonnante"
        case .warm: return "Chaleureuse"
        case .bright: return "Claire"
        case .nasal: return "Nasale"
        case .sharp: return "Stridente"
        case .soft: return "Douce"
        case .powerful: return "Puissante"
        case .fragile: return "Fragile"
        case .natural: return "Naturelle"
        }
    }

    var prompt: String {
        switch self {
        case .deep: return "a deep timbre"
        case .lowPitched: return "a low pitch"
        case .highPitched: return "a high pitch"
        case .raspy: return "a raspy texture"
        case .hoarse: return "a hoarse and slightly rough texture"
        case .breathy: return "an airy, breathy texture"
        case .smoky: return "a smoky texture"
        case .gravelly: return "a gravelly texture"
        case .tremulous: return "a subtle age-related vocal tremor"
        case .thin: return "a thin, light resonance"
        case .resonant: return "strong chest resonance"
        case .warm: return "a warm timbre"
        case .bright: return "a bright, clear timbre"
        case .nasal: return "a nasal resonance"
        case .sharp: return "a piercing, strident edge"
        case .soft: return "a soft, gentle attack"
        case .powerful: return "a powerful, projected voice"
        case .fragile: return "a fragile, low-energy voice"
        case .natural: return "a natural, unforced vocal texture"
        }
    }
}

enum VoiceDesignMood: String, CaseIterable, Identifiable {
    case neutral
    case joyful
    case melancholic
    case sinister
    case mysterious
    case anxious
    case angry
    case tender
    case solemn
    case exhausted
    case ironic

    var id: Self { self }

    var label: String {
        switch self {
        case .neutral: return "Neutre"
        case .joyful: return "Joyeuse"
        case .melancholic: return "Mélancolique"
        case .sinister: return "Sinistre"
        case .mysterious: return "Mystérieuse"
        case .anxious: return "Anxieuse"
        case .angry: return "Colérique"
        case .tender: return "Tendre"
        case .solemn: return "Solennelle"
        case .exhausted: return "Épuisée"
        case .ironic: return "Ironique"
        }
    }

    var prompt: String {
        switch self {
        case .neutral: return "Emotionally balanced and composed"
        case .joyful: return "Joyful, lively and smiling in tone"
        case .melancholic: return "Melancholic, subdued and reflective"
        case .sinister: return "Sinister, ominous and unsettling"
        case .mysterious: return "Mysterious, restrained and intriguing"
        case .anxious: return "Anxious, tense and slightly hurried"
        case .angry: return "Angry, forceful and controlled"
        case .tender: return "Tender, intimate and reassuring"
        case .solemn: return "Solemn, dignified and serious"
        case .exhausted: return "Exhausted, weak and short of breath"
        case .ironic: return "Dryly ironic with subtle amusement"
        }
    }
}

enum VoiceDesignReadingStyle: String, CaseIterable, Identifiable {
    case literaryNarration
    case thriller
    case formal
    case documentary
    case fairyTale
    case romance
    case comedy
    case horror
    case intimate
    case epic
    case conversational

    var id: Self { self }

    var label: String {
        switch self {
        case .literaryNarration: return "Narration littéraire"
        case .thriller: return "Roman à suspense"
        case .formal: return "Lecture formelle"
        case .documentary: return "Documentaire"
        case .fairyTale: return "Conte de fées"
        case .romance: return "Roman d'amour"
        case .comedy: return "Humour"
        case .horror: return "Horreur"
        case .intimate: return "Lecture intime"
        case .epic: return "Épique"
        case .conversational: return "Conversation naturelle"
        }
    }

    var prompt: String {
        switch self {
        case .literaryNarration:
            return "Read as nuanced literary audiobook narration, measured and expressive"
        case .thriller:
            return "Read as suspenseful thriller narration, controlled tension, deliberate pauses"
        case .formal:
            return "Read in a formal, precise and restrained manner"
        case .documentary:
            return "Read as authoritative documentary narration, informative and steady"
        case .fairyTale:
            return "Read as enchanting fairy-tale storytelling, warm and imaginative"
        case .romance:
            return "Read as intimate romantic-fiction narration, warm and emotionally nuanced"
        case .comedy:
            return "Read with natural comic timing, playful emphasis and light irony"
        case .horror:
            return "Read as atmospheric horror narration, slow, ominous and unsettling"
        case .intimate:
            return "Read closely and intimately, as if speaking to one listener"
        case .epic:
            return "Read as grand epic narration, resonant and dramatic without shouting"
        case .conversational:
            return "Read in a spontaneous conversational style with natural phrasing"
        }
    }
}
