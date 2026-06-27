import Foundation
import SwiftData

/// Eine Planungs-Sitzung: hält den aktuellen Plan zusammen mit dem Kontext und den Kandidaten,
/// damit eine Ablehnung (Umverteilung) ohne erneutes Laden möglich ist.
struct PlanSitzung {
    var plan: PlanErgebnis
    var kontext: PlanKontext
    var kandidaten: [FoodKandidat]
    var profilName: String
}

/// Baut Planungs-Sitzungen aus den SwiftData-Daten und kapselt Annehmen/Ablehnen inkl. Lernen.
enum PlanBerechnung {

    /// Erstellt eine frische Sitzung für „jetzt".
    static func sitzung(context: ModelContext, settings: AppSettings, jetzt: Date = Date()) -> PlanSitzung? {
        guard let profil = Tagesdaten.aktivesProfil(context: context) else { return nil }

        let foods = (try? context.fetch(FetchDescriptor<Food>())) ?? []
        let logs = Tagesdaten.letzteLogs(context: context, tage: 7, jetzt: jetzt)
        let kandidaten = EngineAdapter.kandidaten(aus: foods, logs: logs, jetzt: jetzt)

        let gegessen = Tagesdaten.gegessenKcal(Tagesdaten.logs(context: context, datum: jetzt))
        let kontext = EngineAdapter.planKontext(
            settings: settings, profil: profil,
            jetzt: Uhrzeit.aus(date: jetzt), bereitsGegessenKcal: gegessen)

        let plan = PlanningEngine.erstellePlan(kontext: kontext, kandidaten: kandidaten)
        return PlanSitzung(plan: plan, kontext: kontext, kandidaten: kandidaten, profilName: profil.name)
    }

    /// Lehnt den Vorschlag eines Slots ab → Umverteilung + neuer Vorschlag. Senkt zudem den magScore.
    static func ablehnen(slotId: UUID, sitzung: inout PlanSitzung, context: ModelContext) {
        if let foodId = sitzung.plan.slots.first(where: { $0.id == slotId })?.vorschlag?.foodId {
            magScoreAendern(foodId: foodId, delta: -5, context: context)
        }
        sitzung.plan = PlanningEngine.lehneAb(
            slotId: slotId, plan: sitzung.plan,
            kontext: sitzung.kontext, kandidaten: sitzung.kandidaten)
    }

    /// Nimmt den Vorschlag an → erhöht den magScore (Lernen).
    static func annehmen(slotId: UUID, sitzung: PlanSitzung, context: ModelContext) {
        guard let foodId = sitzung.plan.slots.first(where: { $0.id == slotId })?.vorschlag?.foodId else { return }
        magScoreAendern(foodId: foodId, delta: +5, context: context)
    }

    private static func magScoreAendern(foodId: UUID, delta: Double, context: ModelContext) {
        let pred = #Predicate<Food> { $0.id == foodId }
        guard let food = (try? context.fetch(FetchDescriptor<Food>(predicate: pred)))?.first else { return }
        food.magScore = min(100, max(0, food.magScore + delta))
        try? context.save()
    }
}
