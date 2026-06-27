import Foundation
import SwiftData

/// Vorlage für einen Essens-Slot innerhalb eines RoutineProfils.
/// Reiner Codable-Werttyp – wird als Array im RoutineProfil gespeichert.
struct SlotVorlage: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var stunde: Int = 12
    var minute: Int = 0
    /// Anteil dieses Slots am Tagesbudget in Prozent (Summe der Slots sollte ~100 ergeben).
    var gewichtProzent: Double = 25
    var kochenErlaubt: Bool = true
    var istShakeSlot: Bool = false
    var tageszeit: Tageszeit = .egal

    var uhrzeit: Uhrzeit { Uhrzeit(stunde, minute) }
}

/// Ein Tagesablauf-Profil (z. B. „Arbeitstag", „Wochenende"). Mehrere anlegbar, eines ist aktiv.
@Model
final class RoutineProfil {
    var id: UUID = UUID()
    var name: String = ""
    var aktiv: Bool = false

    var aufwachStunde: Int = 7
    var aufwachMinute: Int = 0
    /// Letzte Essenszeit – nach dem Cutoff plant die Engine nichts mehr.
    var cutoffStunde: Int = 21
    var cutoffMinute: Int = 0

    /// Essensfenster inkl. Gewichtung, Koch-Erlaubnis und Shake-Markierung.
    var slots: [SlotVorlage] = []

    init(
        id: UUID = UUID(),
        name: String = "",
        aktiv: Bool = false,
        aufwachStunde: Int = 7,
        aufwachMinute: Int = 0,
        cutoffStunde: Int = 21,
        cutoffMinute: Int = 0,
        slots: [SlotVorlage] = []
    ) {
        self.id = id
        self.name = name
        self.aktiv = aktiv
        self.aufwachStunde = aufwachStunde
        self.aufwachMinute = aufwachMinute
        self.cutoffStunde = cutoffStunde
        self.cutoffMinute = cutoffMinute
        self.slots = slots
    }

    var aufwachzeit: Uhrzeit { Uhrzeit(aufwachStunde, aufwachMinute) }
    var cutoff: Uhrzeit { Uhrzeit(cutoffStunde, cutoffMinute) }
}
