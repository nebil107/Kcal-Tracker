import Foundation
import SwiftData

/// Behälter (Teller, Schüssel, …) mit Tara-Gewicht. Frei anlegbar/änderbar/löschbar.
/// Beim Loggen wird `tara_g` automatisch vom Bruttogewicht abgezogen.
@Model
final class Behaelter {
    var id: UUID = UUID()
    var name: String = ""
    var tara_g: Double = 0

    init(id: UUID = UUID(), name: String = "", tara_g: Double = 0) {
        self.id = id
        self.name = name
        self.tara_g = tara_g
    }
}
