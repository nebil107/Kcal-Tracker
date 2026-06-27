import Foundation
import SwiftData

/// Ein protokollierter Verzehr. Speichert die berechneten Werte selbst, damit der Eintrag
/// auch dann korrekt bleibt, wenn das zugrunde liegende `Food` später geändert oder gelöscht wird.
@Model
final class LogEntry {
    var id: UUID = UUID()
    var zeitstempel: Date = Date()

    var food: Food?
    /// Name-Snapshot für die Anzeige, falls das Food gelöscht wird.
    var foodName: String = ""

    var bruttogewicht_g: Double = 0
    var behaelter: Behaelter?
    var tara_g: Double = 0
    var netto_g: Double = 0

    var istFestePortion: Bool = false
    var portionen: Double = 0

    // Berechnete Nährwerte zum Zeitpunkt des Eintrags.
    var kcal: Double = 0
    var protein: Double = 0
    var fett: Double = 0
    var kohlenhydrate: Double = 0

    var tageszeit: Tageszeit = Tageszeit.egal

    init(
        id: UUID = UUID(),
        zeitstempel: Date = Date(),
        foodName: String = "",
        bruttogewicht_g: Double = 0,
        tara_g: Double = 0,
        netto_g: Double = 0,
        istFestePortion: Bool = false,
        portionen: Double = 0,
        kcal: Double = 0,
        protein: Double = 0,
        fett: Double = 0,
        kohlenhydrate: Double = 0,
        tageszeit: Tageszeit = .egal
    ) {
        self.id = id
        self.zeitstempel = zeitstempel
        self.foodName = foodName
        self.bruttogewicht_g = bruttogewicht_g
        self.tara_g = tara_g
        self.netto_g = netto_g
        self.istFestePortion = istFestePortion
        self.portionen = portionen
        self.kcal = kcal
        self.protein = protein
        self.fett = fett
        self.kohlenhydrate = kohlenhydrate
        self.tageszeit = tageszeit
    }

    var makros: Makros {
        Makros(protein: protein, fett: fett, kohlenhydrate: kohlenhydrate)
    }
}
