import Foundation
@testable import KalorienPlaner

// Fabrik-Funktionen, damit die Tests die Engine-Werttypen knapp und lesbar aufbauen können.

func macheKandidat(
    id: UUID = UUID(),
    name: String = "Test",
    kategorie: String = "Allgemein",
    kcalPro100g: Double = 100,
    proteinPro100g: Double = 5,
    fettPro100g: Double = 3,
    khPro100g: Double = 15,
    istFestePortion: Bool = false,
    festeKcal: Double = 0,
    festeMakros: Makros = .null,
    portionsName: String = "Portion",
    standardPortion_g: Double = 200,
    magScore: Double = 50,
    nieVorschlagen: Bool = false,
    kochAufwand: KochAufwand = .keiner,
    tageszeiten: [Tageszeit] = [.egal],
    shakeTauglich: Bool = false,
    zuletztGegessenVorTagen: Double? = nil
) -> FoodKandidat {
    FoodKandidat(
        id: id, name: name, kategorie: kategorie,
        kcalPro100g: kcalPro100g, proteinPro100g: proteinPro100g,
        fettPro100g: fettPro100g, kohlenhydratePro100g: khPro100g,
        istFestePortion: istFestePortion, festeKcal: festeKcal,
        festeMakros: festeMakros, portionsName: portionsName,
        standardPortion_g: standardPortion_g, magScore: magScore,
        nieVorschlagen: nieVorschlagen, kochAufwand: kochAufwand,
        tageszeiten: tageszeiten, shakeTauglich: shakeTauglich,
        zuletztGegessenVorTagen: zuletztGegessenVorTagen)
}

func macheSlot(
    id: UUID = UUID(),
    stunde: Int,
    minute: Int = 0,
    gewicht: Double = 25,
    kochenErlaubt: Bool = true,
    istShakeSlot: Bool = false,
    tageszeit: Tageszeit = .egal
) -> SlotEingabe {
    SlotEingabe(id: id, uhrzeit: Uhrzeit(stunde, minute), gewicht: gewicht,
                kochenErlaubt: kochenErlaubt, istShakeSlot: istShakeSlot, tageszeit: tageszeit)
}

func macheKontext(
    kcalZiel: Double = 3000,
    slots: [SlotEingabe],
    cutoff: Uhrzeit = Uhrzeit(22),
    jetzt: Uhrzeit = Uhrzeit(6),
    vorliebe: PlanungsVorliebe = .wenigeGrosse,
    shakeProTag: Int = 0,
    bereitsGegessenKcal: Double = 0,
    shakeMindestKcal: Double = 400,
    maxSlotFaktor: Double = 2.0,
    makroZiel: Makros = Makros(protein: 225, fett: 83, kohlenhydrate: 338)
) -> PlanKontext {
    PlanKontext(
        kcalZiel: kcalZiel, makroZiel: makroZiel, slots: slots, cutoff: cutoff, jetzt: jetzt,
        vorliebe: vorliebe, shakeProTag: shakeProTag, bereitsGegessenKcal: bereitsGegessenKcal,
        shakeMindestKcal: shakeMindestKcal, maxSlotFaktor: maxSlotFaktor)
}
