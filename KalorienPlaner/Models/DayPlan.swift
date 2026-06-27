import Foundation
import SwiftData

/// Tagesplan für ein Datum. Enthält die geplanten Slots, das Tagesziel und den Wasserstand.
@Model
final class DayPlan {
    var id: UUID = UUID()
    /// Auf Tagesbeginn normalisiertes Datum.
    var datum: Date = Calendar.current.startOfDay(for: Date())
    var kcalZiel: Double = 3000
    var wasserZiel_ml: Double = 3000
    var wasserGetrunken_ml: Double = 0

    @Relationship(deleteRule: .cascade, inverse: \MealSlot.dayPlan)
    var slots: [MealSlot] = []

    var aktivesRoutineProfil: RoutineProfil?

    init(
        id: UUID = UUID(),
        datum: Date = Calendar.current.startOfDay(for: Date()),
        kcalZiel: Double = 3000,
        wasserZiel_ml: Double = 3000,
        wasserGetrunken_ml: Double = 0
    ) {
        self.id = id
        self.datum = datum
        self.kcalZiel = kcalZiel
        self.wasserZiel_ml = wasserZiel_ml
        self.wasserGetrunken_ml = wasserGetrunken_ml
    }

    /// Slots in zeitlicher Reihenfolge.
    var slotsSortiert: [MealSlot] {
        slots.sorted { $0.uhrzeit < $1.uhrzeit }
    }
}
