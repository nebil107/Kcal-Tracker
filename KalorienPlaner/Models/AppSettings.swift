import Foundation
import SwiftData

/// Globale, editierbare Einstellungen. Es existiert genau eine Instanz (beim ersten Start angelegt).
/// Default-Kalorienziel = 3000; Makro-Ziele werden daraus berechnet (30 % P / 25 % F / 45 % KH),
/// sind aber frei überschreibbar.
@Model
final class AppSettings {
    var id: UUID = UUID()

    var kcalZiel: Double = 3000

    // Makro-Ziele in Gramm (das ist die angezeigte „Wahrheit").
    var zielProtein_g: Double = 225
    var zielFett_g: Double = 83.3
    var zielKohlenhydrate_g: Double = 337.5

    // Prozent-Aufteilung für die automatische Neuberechnung aus kcalZiel.
    var proteinProzent: Double = 0.30
    var fettProzent: Double = 0.25
    var khProzent: Double = 0.45
    /// Wenn true, werden die Gramm-Ziele bei Änderung des kcalZiels automatisch neu berechnet.
    var makrosAutomatisch: Bool = true

    var wasserZiel_ml: Double = 3000

    var planungsVorliebe: PlanungsVorliebe = PlanungsVorliebe.wenigeGrosse
    var shakeProTag: Int = 1
    /// Mindest-kcal je Shake – der Shake wird zuerst eingeplant (höchste Priorität).
    var shakeMindestKcal: Double = 400
    /// Obergrenze je Slot = maxSlotFaktor × fairer Anteil.
    var maxSlotFaktor: Double = 2.0

    // Status-Flags.
    var seedImportiert: Bool = false
    var benachrichtigungenAktiv: Bool = false
    var wasserErinnerungAktiv: Bool = false

    // Optionaler Cloud-Sync (selbst-gehosteter Server). Leer = aus → App bleibt rein offline.
    // Diese Felder werden bewusst NICHT ins JSON-Backup aufgenommen (Geheimnis bleibt lokal).
    var syncServerURL: String = ""
    var syncAPIKey: String = ""
    var syncVersion: Int = 0
    var syncZuletzt: Date?

    init() {}

    /// True, wenn URL und Schlüssel gesetzt sind.
    var syncKonfiguriert: Bool {
        !syncServerURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !syncAPIKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Berechnet die Gramm-Ziele aus kcalZiel und den Prozent-Anteilen (Atwater 4/9/4).
    func makrosAusKcalNeuBerechnen() {
        zielProtein_g = (kcalZiel * proteinProzent) / 4.0
        zielFett_g = (kcalZiel * fettProzent) / 9.0
        zielKohlenhydrate_g = (kcalZiel * khProzent) / 4.0
    }

    /// Makro-Ziele als Werttyp für die Engine.
    var makroZiel: Makros {
        Makros(protein: zielProtein_g, fett: zielFett_g, kohlenhydrate: zielKohlenhydrate_g)
    }
}
