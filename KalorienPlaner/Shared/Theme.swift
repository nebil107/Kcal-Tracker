import SwiftUI
import UIKit

/// Zentrale Stelle für Farben, Abstände und Makro-Farbcodes.
///
/// Wichtig laut Spezifikation: Wenn der Nutzer Zielwerte (z. B. das kcal-Ziel von 3000 auf einen
/// anderen Wert) ändert, darf das Layout nicht „kaputtgehen". Deshalb werden Farben und Abstände
/// hier gebündelt und nirgends hartkodiert – Werte fließen immer als Daten in die Views.
enum Theme {

    // MARK: - Abstände
    enum Abstand {
        static let klein: CGFloat = 8
        static let mittel: CGFloat = 16
        static let gross: CGFloat = 24
        static let eckenradius: CGFloat = 16
    }

    // MARK: - Farben
    /// Akzentfarbe der App (kommt aus dem Asset-Katalog „AccentColor").
    static let akzent = Color.accentColor

    static let protein = Color(red: 0.90, green: 0.30, blue: 0.35)   // Rot-Ton
    static let fett = Color(red: 0.95, green: 0.70, blue: 0.20)      // Gelb/Orange-Ton
    static let kohlenhydrate = Color(red: 0.25, green: 0.55, blue: 0.90) // Blau-Ton
    static let wasser = Color(red: 0.20, green: 0.65, blue: 0.90)

    static let warnung = Color.orange
    static let fehler = Color.red

    /// Hintergrund für Karten/Kacheln – passt sich automatisch an Hell/Dunkel an.
    static let kartenHintergrund = Color(uiColor: .secondarySystemBackground)
}
