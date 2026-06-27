import Foundation

// Reine Werttypen für die Planungs-Engine. KEIN Import von SwiftData/SwiftUI.
// Dadurch ist die Engine vollständig ohne ModelContainer testbar.

/// Eine Tageszeit (Stunde:Minute), unabhängig von Datum und Zeitzone.
struct Uhrzeit: Codable, Hashable, Comparable {
    var stunde: Int
    var minute: Int

    init(_ stunde: Int, _ minute: Int = 0) {
        self.stunde = stunde
        self.minute = minute
    }

    /// Minuten seit Mitternacht – Grundlage für Vergleiche und Zeitfenster-Rechnung.
    var minutenAbMitternacht: Int { stunde * 60 + minute }

    static func < (lhs: Uhrzeit, rhs: Uhrzeit) -> Bool {
        lhs.minutenAbMitternacht < rhs.minutenAbMitternacht
    }

    /// Aktuelle Uhrzeit aus einem `Date` (z. B. für „jetzt“).
    static func aus(date: Date, kalender: Calendar = .current) -> Uhrzeit {
        let c = kalender.dateComponents([.hour, .minute], from: date)
        return Uhrzeit(c.hour ?? 0, c.minute ?? 0)
    }

    var anzeige: String { String(format: "%02d:%02d", stunde, minute) }
}

/// Makronährwerte in Gramm.
struct Makros: Codable, Hashable {
    var protein: Double
    var fett: Double
    var kohlenhydrate: Double

    static let null = Makros(protein: 0, fett: 0, kohlenhydrate: 0)

    static func + (l: Makros, r: Makros) -> Makros {
        Makros(protein: l.protein + r.protein,
               fett: l.fett + r.fett,
               kohlenhydrate: l.kohlenhydrate + r.kohlenhydrate)
    }

    static func * (m: Makros, faktor: Double) -> Makros {
        Makros(protein: m.protein * faktor,
               fett: m.fett * faktor,
               kohlenhydrate: m.kohlenhydrate * faktor)
    }

    /// Energiegehalt laut Atwater-Faktoren (4/9/4 kcal je g). Nur zur Plausibilität/Anzeige.
    var kcalAusMakros: Double { protein * 4 + fett * 9 + kohlenhydrate * 4 }
}

// MARK: - Eingaben für die Engine

/// Lebensmittel-Kandidat (reiner Werttyp, aus einem `Food` abgeleitet via EngineAdapter).
struct FoodKandidat: Identifiable {
    let id: UUID
    let name: String
    let kategorie: String

    // Variable Lebensmittel: Nährwerte je 100 g.
    let kcalPro100g: Double
    let proteinPro100g: Double
    let fettPro100g: Double
    let kohlenhydratePro100g: Double

    // Feste Portion (z. B. „1 Riegel“) – dann keine Gramm-Rechnung.
    let istFestePortion: Bool
    let festeKcal: Double
    let festeMakros: Makros
    let portionsName: String

    let standardPortion_g: Double
    let magScore: Double
    let nieVorschlagen: Bool
    let kochAufwand: KochAufwand
    let tageszeiten: [Tageszeit]
    let shakeTauglich: Bool

    /// Tage seit dem letzten Verzehr (nil = noch nie) – steuert die VarietyPenalty.
    let zuletztGegessenVorTagen: Double?

    /// kcal pro Gramm (für variable Lebensmittel bzw. Shake-Komponenten).
    var kcalProGramm: Double {
        if istFestePortion {
            return standardPortion_g > 0 ? festeKcal / standardPortion_g : 0
        }
        return kcalPro100g / 100.0
    }

    /// Makros pro Gramm. Bei fester Portion aus den festen Makros je Standardportion abgeleitet,
    /// damit auch feste Zutaten als Shake-Komponente sinnvolle Makros liefern.
    var makrosProGramm: Makros {
        if istFestePortion {
            guard standardPortion_g > 0 else { return .null }
            return festeMakros * (1.0 / standardPortion_g)
        }
        return Makros(protein: proteinPro100g / 100.0,
                      fett: fettPro100g / 100.0,
                      kohlenhydrate: kohlenhydratePro100g / 100.0)
    }
}

/// Slot-Vorgabe (aus einer SlotVorlage des aktiven RoutineProfils abgeleitet).
struct SlotEingabe: Identifiable {
    let id: UUID
    let uhrzeit: Uhrzeit
    /// Relative Gewichtung des Slots (z. B. Prozentwert). Summe muss nicht 100 ergeben.
    let gewicht: Double
    let kochenErlaubt: Bool
    let istShakeSlot: Bool
    let tageszeit: Tageszeit
}

/// Gesamter Kontext eines Tagesplans (alles editierbar, kommt aus AppSettings/RoutineProfil).
struct PlanKontext {
    var kcalZiel: Double
    var makroZiel: Makros
    var slots: [SlotEingabe]
    var cutoff: Uhrzeit
    var jetzt: Uhrzeit
    var vorliebe: PlanungsVorliebe
    var shakeProTag: Int
    var bereitsGegessenKcal: Double
    /// Mindest-kcal je Shake (Shake wird zuerst reserviert, bevor andere Slots gefüllt werden).
    var shakeMindestKcal: Double
    /// Obergrenze je Slot = maxSlotFaktor × fairer Anteil. Verhindert „alles in ein Fenster“.
    var maxSlotFaktor: Double
}

// MARK: - Ausgaben der Engine

/// Eine Komponente eines zusammengestellten Shakes.
struct ShakeKomponente: Identifiable {
    let id = UUID()
    let foodId: UUID
    let name: String
    let menge_g: Double
    let kcal: Double
    let makros: Makros
}

/// Zusammengestellter Shake-Vorschlag (überschreibbar durch den Nutzer).
struct ShakeVorschlag {
    var komponenten: [ShakeKomponente]
    var gesamtKcal: Double
    var gesamtMakros: Makros
}

/// Vorschlag für einen Slot – entweder ein einzelnes Lebensmittel oder ein Shake.
struct Vorschlag {
    let foodId: UUID
    let name: String
    let istShake: Bool
    let menge_g: Double?       // variable Lebensmittel
    let portionen: Double?     // feste Portion
    let portionsName: String?
    let kcal: Double
    let makros: Makros
    let shake: ShakeVorschlag?
}

/// Ein geplanter Slot inkl. Budget und (optionalem) Vorschlag.
struct GeplanterSlot: Identifiable {
    let id: UUID
    let uhrzeit: Uhrzeit
    var kcalBudget: Double
    let istShakeSlot: Bool
    let kochenErlaubt: Bool
    let tageszeit: Tageszeit
    var vorschlag: Vorschlag?
}

/// Wächter-Hinweis an den Nutzer.
struct Warnung: Identifiable {
    enum Art: String {
        case rueckstand
        case zielUnrealistisch
        case slotUebervoll
        case keinShakeMoeglich
        case keineKandidaten
    }
    let id = UUID()
    let art: Art
    let text: String
}

/// Ergebnis eines Planungslaufs.
struct PlanErgebnis {
    var slots: [GeplanterSlot]
    var warnungen: [Warnung]

    /// Summe der kcal aller Vorschläge.
    var geplanteKcal: Double {
        slots.reduce(0) { $0 + ($1.vorschlag?.kcal ?? 0) }
    }
}
