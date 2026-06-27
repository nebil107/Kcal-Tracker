import Foundation
import SwiftData

/// Ein konkret geplanter Slot eines Tages. Hält den von der Engine erzeugten Vorschlag als
/// Snapshot (damit Status & Vorschlag einen App-Neustart überleben) und den Bezug zum gewählten Food.
@Model
final class MealSlot {
    var id: UUID = UUID()
    var stunde: Int = 12
    var minute: Int = 0
    var kcalBudget: Double = 0
    var kochenErlaubt: Bool = true
    var istShakeSlot: Bool = false
    var tageszeit: Tageszeit = Tageszeit.egal
    var status: SlotStatus = SlotStatus.geplant

    // Vorschlag-Snapshot aus dem Planungslauf.
    var vorgeschlagenesFood: Food?
    var vorschlagMenge_g: Double?
    var vorschlagPortionen: Double?
    var vorschlagKcal: Double = 0
    var vorschlagProtein: Double = 0
    var vorschlagFett: Double = 0
    var vorschlagKohlenhydrate: Double = 0
    var istShakeVorschlag: Bool = false
    /// Lesbare Shake-Zusammensetzung (Komponenten), falls dieser Slot ein Shake ist.
    var shakeBeschreibung: String?

    // Was tatsächlich gegessen wurde (kann vom Vorschlag abweichen).
    var tatsaechlichesFood: Food?

    // Rückbeziehung zum Tagesplan (Inverse wird auf DayPlan.slots deklariert).
    var dayPlan: DayPlan?

    init(
        id: UUID = UUID(),
        stunde: Int = 12,
        minute: Int = 0,
        kcalBudget: Double = 0,
        kochenErlaubt: Bool = true,
        istShakeSlot: Bool = false,
        tageszeit: Tageszeit = .egal,
        status: SlotStatus = .geplant
    ) {
        self.id = id
        self.stunde = stunde
        self.minute = minute
        self.kcalBudget = kcalBudget
        self.kochenErlaubt = kochenErlaubt
        self.istShakeSlot = istShakeSlot
        self.tageszeit = tageszeit
        self.status = status
    }

    var uhrzeit: Uhrzeit { Uhrzeit(stunde, minute) }
}
