import XCTest
@testable import KalorienPlaner

final class PlanningEngineTests: XCTestCase {

    /// Die Budgetverteilung muss (mit variablen Lebensmitteln) genau das Tagesziel ausschöpfen.
    func testVerteilungSummiertAufZiel() {
        let foods = [macheKandidat(name: "A"), macheKandidat(name: "B")]
        let slots = [macheSlot(stunde: 8), macheSlot(stunde: 12), macheSlot(stunde: 16), macheSlot(stunde: 20)]
        let kontext = macheKontext(slots: slots, shakeProTag: 0)

        let plan = PlanningEngine.erstellePlan(kontext: kontext, kandidaten: foods)

        XCTAssertEqual(plan.slots.count, 4)
        XCTAssertEqual(plan.geplanteKcal, 3000, accuracy: 1.0)
        XCTAssertFalse(plan.warnungen.contains { $0.art == .zielUnrealistisch })
        XCTAssertTrue(plan.slots.allSatisfy { $0.kcalBudget > 0 })
    }

    /// „Bereits gegessen" muss vom verbleibenden Budget abgezogen werden.
    func testBereitsGegessenReduziertRest() {
        let foods = [macheKandidat(name: "A")]
        let slots = [macheSlot(stunde: 10), macheSlot(stunde: 14), macheSlot(stunde: 18)]
        let kontext = macheKontext(slots: slots, shakeProTag: 0, bereitsGegessenKcal: 1200)

        let plan = PlanningEngine.erstellePlan(kontext: kontext, kandidaten: foods)
        XCTAssertEqual(plan.geplanteKcal, 1800, accuracy: 1.0) // 3000 − 1200
    }

    /// In jeden Plan gehört mindestens ein Shake – auch wenn das Profil keinen Shake-Slot hat.
    func testShakeImmerEingeplant() {
        let foods = [
            macheKandidat(name: "Milch", kcalPro100g: 64, proteinPro100g: 3.4, fettPro100g: 3.6, khPro100g: 4.8, magScore: 70, shakeTauglich: true),
            macheKandidat(name: "Haferflocken", kcalPro100g: 370, magScore: 60, shakeTauglich: true),
            macheKandidat(name: "Reis", kcalPro100g: 130, magScore: 50, shakeTauglich: false)
        ]
        let slots = [macheSlot(stunde: 8), macheSlot(stunde: 13), macheSlot(stunde: 19)]
        let kontext = macheKontext(slots: slots, shakeProTag: 1)

        let plan = PlanningEngine.erstellePlan(kontext: kontext, kandidaten: foods)
        XCTAssertTrue(plan.slots.contains { $0.vorschlag?.istShake == true },
                      "Mindestens ein Slot muss ein Shake sein")
    }

    /// Slots vor „jetzt" oder nach dem Cutoff dürfen nicht geplant werden.
    func testCutoffWirdRespektiert() {
        let foods = [macheKandidat(name: "A")]
        let slots = [
            macheSlot(stunde: 8), macheSlot(stunde: 12), macheSlot(stunde: 18),
            macheSlot(stunde: 21), macheSlot(stunde: 23)
        ]
        // jetzt 17:00, cutoff 22:00 → nur 18:00 und 21:00 sind plannbar.
        let kontext = macheKontext(slots: slots, cutoff: Uhrzeit(22), jetzt: Uhrzeit(17), shakeProTag: 0)

        let plan = PlanningEngine.erstellePlan(kontext: kontext, kandidaten: foods)
        XCTAssertEqual(plan.slots.count, 2)
        XCTAssertTrue(plan.slots.allSatisfy { $0.uhrzeit >= Uhrzeit(17) && $0.uhrzeit <= Uhrzeit(22) })
    }

    /// Ablehnung („mehrere kleine"): anderes Food im Slot, kleineres Budget hier, Ziel bleibt erhalten.
    func testAblehnungMehrereKleine() {
        let a = macheKandidat(name: "A", magScore: 90)
        let b = macheKandidat(name: "B", magScore: 70)
        let c = macheKandidat(name: "C", magScore: 50)
        let foods = [a, b, c]
        let slots = [macheSlot(stunde: 8), macheSlot(stunde: 13), macheSlot(stunde: 19)]
        let kontext = macheKontext(slots: slots, vorliebe: .mehrereKleine, shakeProTag: 0)

        let plan = PlanningEngine.erstellePlan(kontext: kontext, kandidaten: foods)
        let slotId = plan.slots[0].id
        XCTAssertEqual(plan.slots[0].vorschlag?.foodId, a.id) // höchster magScore zuerst
        let budgetVorher = plan.slots[0].kcalBudget

        let neu = PlanningEngine.lehneAb(slotId: slotId, plan: plan, kontext: kontext, kandidaten: foods)
        let neuerSlot = neu.slots.first { $0.id == slotId }
        XCTAssertNotEqual(neuerSlot?.vorschlag?.foodId, a.id, "Abgelehntes Food darf nicht erneut kommen")
        XCTAssertLessThan(neuerSlot!.kcalBudget, budgetVorher, "Bei „mehrere kleine" schrumpft der Slot")
        XCTAssertEqual(neu.geplanteKcal, 3000, accuracy: 1.0) // Ziel bleibt erhalten
    }

    /// Ablehnung („wenige große"): gleiches Budget, aber anderes Gericht.
    func testAblehnungWenigeGrosse() {
        let a = macheKandidat(name: "A", magScore: 90)
        let b = macheKandidat(name: "B", magScore: 70)
        let foods = [a, b]
        let slots = [macheSlot(stunde: 8), macheSlot(stunde: 13), macheSlot(stunde: 19)]
        let kontext = macheKontext(slots: slots, vorliebe: .wenigeGrosse, shakeProTag: 0)

        let plan = PlanningEngine.erstellePlan(kontext: kontext, kandidaten: foods)
        let slotId = plan.slots[0].id
        let budgetVorher = plan.slots[0].kcalBudget

        let neu = PlanningEngine.lehneAb(slotId: slotId, plan: plan, kontext: kontext, kandidaten: foods)
        let neuerSlot = neu.slots.first { $0.id == slotId }
        XCTAssertEqual(neuerSlot?.vorschlag?.foodId, b.id)
        XCTAssertEqual(neuerSlot!.kcalBudget, budgetVorher, accuracy: 1.0, "Bei „wenige große" bleibt das Budget gleich")
    }

    /// nieVorschlagen schließt ein Lebensmittel hart aus.
    func testNieVorschlagenAusgeschlossen() {
        let gesperrt = macheKandidat(name: "Gesperrt", magScore: 100, nieVorschlagen: true)
        let normal = macheKandidat(name: "Normal", magScore: 40)
        let slots = [macheSlot(stunde: 9), macheSlot(stunde: 15)]
        let kontext = macheKontext(slots: slots, shakeProTag: 0)

        let plan = PlanningEngine.erstellePlan(kontext: kontext, kandidaten: [gesperrt, normal])
        XCTAssertTrue(plan.slots.allSatisfy { $0.vorschlag?.foodId == normal.id })
    }

    /// Rückstand: spät am Tag mit hohem Restbudget → Warnung + größere Portionen.
    func testRueckstandWarnung() {
        let foods = [macheKandidat(name: "A")]
        // 4 Slots im Profil, aber jetzt 19:00 → nur der 20:00-Slot ist plannbar; 3000 kcal müssen rein.
        let slots = [macheSlot(stunde: 8), macheSlot(stunde: 12), macheSlot(stunde: 16), macheSlot(stunde: 20)]
        let kontext = macheKontext(slots: slots, cutoff: Uhrzeit(22), jetzt: Uhrzeit(19), shakeProTag: 0)

        let plan = PlanningEngine.erstellePlan(kontext: kontext, kandidaten: foods)
        XCTAssertTrue(plan.warnungen.contains { $0.art == .rueckstand })
    }
}
