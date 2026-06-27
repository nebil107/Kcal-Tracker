import Foundation

// Gemeinsame Aufzählungstypen. Bewusst KEINE feste „Kategorie“-Enum:
// Kategorien sind freie Texte (siehe Food.kategorie), damit der Nutzer beliebig
// neue Kategorien anlegen kann ("alles erweiterbar").

/// Tageszeit-Zuordnung – für die Planung (welche Speise passt wann) und Slot-Klassifizierung.
enum Tageszeit: String, Codable, CaseIterable, Identifiable, Hashable {
    case fruehstueck
    case mittag
    case abend
    case snack
    case egal

    var id: String { rawValue }

    var anzeige: String {
        switch self {
        case .fruehstueck: return "Frühstück"
        case .mittag: return "Mittag"
        case .abend: return "Abend"
        case .snack: return "Snack"
        case .egal: return "Egal"
        }
    }

    /// Grobe Einordnung einer Uhrzeit – nur als Metadatum für Log-Einträge (nicht für die Planung,
    /// dort steuert die pro Slot gewählte Tageszeit).
    static func ausUhrzeit(_ u: Uhrzeit) -> Tageszeit {
        switch u.stunde {
        case ..<11: return .fruehstueck
        case 11..<15: return .mittag
        case 15..<17: return .snack
        default: return .abend
        }
    }
}

/// Wie aufwändig die Zubereitung ist. `geschaetzteMinuten` nutzt die Engine,
/// um in knappen Zeitfenstern No-Cook-Gerichte zu bevorzugen.
enum KochAufwand: String, Codable, CaseIterable, Identifiable, Hashable {
    case keiner
    case wenig
    case mittel
    case hoch

    var id: String { rawValue }

    var anzeige: String {
        switch self {
        case .keiner: return "Kein Kochen"
        case .wenig: return "Wenig"
        case .mittel: return "Mittel"
        case .hoch: return "Hoch"
        }
    }

    /// Grobe Zubereitungsdauer in Minuten – Eingabewert für die Zeitfenster-Logik.
    var geschaetzteMinuten: Int {
        switch self {
        case .keiner: return 0
        case .wenig: return 10
        case .mittel: return 25
        case .hoch: return 45
        }
    }
}

/// Lebenszyklus eines geplanten Slots.
enum SlotStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case geplant
    case angenommen
    case abgelehnt
    case gegessen

    var id: String { rawValue }

    var anzeige: String {
        switch self {
        case .geplant: return "Geplant"
        case .angenommen: return "Angenommen"
        case .abgelehnt: return "Abgelehnt"
        case .gegessen: return "Gegessen"
        }
    }
}

/// Steuert die Tendenz bei der Umverteilung nach einer Ablehnung.
enum PlanungsVorliebe: String, Codable, CaseIterable, Identifiable, Hashable {
    case wenigeGrosse
    case mehrereKleine

    var id: String { rawValue }

    var anzeige: String {
        switch self {
        case .wenigeGrosse: return "Wenige große Mahlzeiten"
        case .mehrereKleine: return "Mehrere kleine Mahlzeiten"
        }
    }
}

/// Eingabe-Einheit beim Loggen. `kilogramm` wird intern in Gramm umgerechnet.
enum Gewichtseinheit: String, CaseIterable, Identifiable, Hashable {
    case gramm
    case kilogramm

    var id: String { rawValue }

    var anzeige: String {
        switch self {
        case .gramm: return "g"
        case .kilogramm: return "kg"
        }
    }
}
