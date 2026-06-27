import Foundation

/// Berechnete Nährwerte (Ergebnis-Typ des Rechners).
struct Naehrwerte: Equatable {
    var kcal: Double
    var protein: Double
    var fett: Double
    var kohlenhydrate: Double

    static let null = Naehrwerte(kcal: 0, protein: 0, fett: 0, kohlenhydrate: 0)

    var makros: Makros { Makros(protein: protein, fett: fett, kohlenhydrate: kohlenhydrate) }
}

/// Reiner Nährwert-/Gewichtsrechner (ohne SwiftData/UI) – Grundlage der Live-Berechnung beim Loggen.
enum NutritionCalculator {

    /// Rechnet eine Gewichtseingabe in Gramm um (kg → g).
    static func inGramm(_ wert: Double, einheit: Gewichtseinheit) -> Double {
        switch einheit {
        case .gramm: return wert
        case .kilogramm: return wert * 1000.0
        }
    }

    /// Netto = Brutto − Tara (nie negativ).
    static func netto_g(brutto_g: Double, tara_g: Double) -> Double {
        max(0, brutto_g - tara_g)
    }

    /// Nährwerte für eine variable Menge (Gramm) auf Basis der Werte je 100 g.
    static func naehrwerte(netto_g: Double, kcalPro100g: Double, proteinPro100g: Double,
                           fettPro100g: Double, khPro100g: Double) -> Naehrwerte {
        let f = netto_g / 100.0
        return Naehrwerte(kcal: kcalPro100g * f, protein: proteinPro100g * f,
                          fett: fettPro100g * f, kohlenhydrate: khPro100g * f)
    }

    /// Nährwerte für feste Portionen (Anzahl × feste Werte).
    static func naehrwerteFestePortion(portionen: Double, festeKcal: Double, festeProtein: Double,
                                       festeFett: Double, festeKh: Double) -> Naehrwerte {
        Naehrwerte(kcal: festeKcal * portionen, protein: festeProtein * portionen,
                   fett: festeFett * portionen, kohlenhydrate: festeKh * portionen)
    }
}
