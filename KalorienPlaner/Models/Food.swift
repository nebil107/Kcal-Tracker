import Foundation
import SwiftData

/// Ein Lebensmittel oder Gericht. Alle Werte sind in der App editierbar.
///
/// Hinweise:
/// - Alle Properties haben Defaults und Beziehungen sind optional → CloudKit-kompatibel
///   (Sync bleibt aber bewusst deaktiviert; siehe Persistence).
/// - `istFestePortion`: Wenn true, zählen die `feste…`-Werte + `portionsName` (keine Gramm-Rechnung).
/// - `kategorie` ist freier Text, damit beliebige neue Kategorien möglich sind.
@Model
final class Food {
    var id: UUID = UUID()
    var name: String = ""
    var kategorie: String = ""

    // Nährwerte je 100 g (für variable Lebensmittel).
    var kcalPro100g: Double = 0
    var proteinPro100g: Double = 0
    var fettPro100g: Double = 0
    var kohlenhydratePro100g: Double = 0

    // Feste Portion (z. B. „1 Riegel = 230 kcal“).
    var istFestePortion: Bool = false
    var festeKcal: Double = 0
    var festeProtein: Double = 0
    var festeFett: Double = 0
    var festeKohlenhydrate: Double = 0
    var portionsName: String = "Portion"

    var standardPortion_g: Double = 100
    /// Beliebtheits-/Vorschlagsgewicht (0…100, Default 50). Steigt beim Annehmen, sinkt beim Ablehnen.
    var magScore: Double = 50
    var nieVorschlagen: Bool = false

    var tags: [String] = []
    var kochAufwand: KochAufwand = KochAufwand.keiner
    var tageszeiten: [Tageszeit] = [Tageszeit.egal]
    var shakeTauglich: Bool = false

    init(
        id: UUID = UUID(),
        name: String = "",
        kategorie: String = "",
        kcalPro100g: Double = 0,
        proteinPro100g: Double = 0,
        fettPro100g: Double = 0,
        kohlenhydratePro100g: Double = 0,
        istFestePortion: Bool = false,
        festeKcal: Double = 0,
        festeProtein: Double = 0,
        festeFett: Double = 0,
        festeKohlenhydrate: Double = 0,
        portionsName: String = "Portion",
        standardPortion_g: Double = 100,
        magScore: Double = 50,
        nieVorschlagen: Bool = false,
        tags: [String] = [],
        kochAufwand: KochAufwand = .keiner,
        tageszeiten: [Tageszeit] = [.egal],
        shakeTauglich: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kategorie = kategorie
        self.kcalPro100g = kcalPro100g
        self.proteinPro100g = proteinPro100g
        self.fettPro100g = fettPro100g
        self.kohlenhydratePro100g = kohlenhydratePro100g
        self.istFestePortion = istFestePortion
        self.festeKcal = festeKcal
        self.festeProtein = festeProtein
        self.festeFett = festeFett
        self.festeKohlenhydrate = festeKohlenhydrate
        self.portionsName = portionsName
        self.standardPortion_g = standardPortion_g
        self.magScore = magScore
        self.nieVorschlagen = nieVorschlagen
        self.tags = tags
        self.kochAufwand = kochAufwand
        self.tageszeiten = tageszeiten
        self.shakeTauglich = shakeTauglich
    }
}
