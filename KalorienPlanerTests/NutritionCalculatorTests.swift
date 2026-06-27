import XCTest
@testable import KalorienPlaner

final class NutritionCalculatorTests: XCTestCase {

    func testNettoAbzug() {
        XCTAssertEqual(NutritionCalculator.netto_g(brutto_g: 350, tara_g: 120), 230, accuracy: 0.0001)
    }

    func testNettoNieNegativ() {
        XCTAssertEqual(NutritionCalculator.netto_g(brutto_g: 50, tara_g: 120), 0, accuracy: 0.0001)
    }

    func testKgInGramm() {
        XCTAssertEqual(NutritionCalculator.inGramm(1.5, einheit: .kilogramm), 1500, accuracy: 0.0001)
        XCTAssertEqual(NutritionCalculator.inGramm(250, einheit: .gramm), 250, accuracy: 0.0001)
    }

    func testVariableNaehrwerte() {
        let n = NutritionCalculator.naehrwerte(netto_g: 200, kcalPro100g: 130,
                                               proteinPro100g: 2.7, fettPro100g: 0.3, khPro100g: 28)
        XCTAssertEqual(n.kcal, 260, accuracy: 0.001)
        XCTAssertEqual(n.protein, 5.4, accuracy: 0.001)
        XCTAssertEqual(n.kohlenhydrate, 56, accuracy: 0.001)
    }

    func testFestePortion() {
        let n = NutritionCalculator.naehrwerteFestePortion(portionen: 2, festeKcal: 230,
                                                           festeProtein: 6, festeFett: 11, festeKh: 27)
        XCTAssertEqual(n.kcal, 460, accuracy: 0.001)
        XCTAssertEqual(n.fett, 22, accuracy: 0.001)
    }

    /// Voller Pfad: Bruttogewicht in kg + Tara → Netto → Nährwerte.
    func testKompletterTaraPfad() {
        let brutto = NutritionCalculator.inGramm(0.6, einheit: .kilogramm) // 600 g
        let netto = NutritionCalculator.netto_g(brutto_g: brutto, tara_g: 250) // 350 g
        XCTAssertEqual(netto, 350, accuracy: 0.0001)
        let n = NutritionCalculator.naehrwerte(netto_g: netto, kcalPro100g: 100,
                                               proteinPro100g: 10, fettPro100g: 5, khPro100g: 12)
        XCTAssertEqual(n.kcal, 350, accuracy: 0.001)
        XCTAssertEqual(n.protein, 35, accuracy: 0.001)
    }
}
