import XCTest
@testable import KalorienPlaner

final class ShakeBuilderTests: XCTestCase {

    /// Der zusammengestellte Shake trifft das vorgegebene kcal-Ziel.
    func testShakeTrifftZiel() {
        let foods = [
            macheKandidat(name: "Milch", kcalPro100g: 64, magScore: 60, shakeTauglich: true),
            macheKandidat(name: "Hafer", kcalPro100g: 370, magScore: 40, shakeTauglich: true)
        ]
        let shake = ShakeBuilder.baue(zielKcal: 500, kandidaten: foods)
        XCTAssertNotNil(shake)
        XCTAssertEqual(shake!.gesamtKcal, 500, accuracy: 0.5)
        XCTAssertFalse(shake!.komponenten.isEmpty)
    }

    /// Ohne shake-taugliche Zutaten gibt es keinen Shake.
    func testKeinShakeOhneTaugliche() {
        let foods = [macheKandidat(name: "Reis", kcalPro100g: 130, shakeTauglich: false)]
        XCTAssertNil(ShakeBuilder.baue(zielKcal: 500, kandidaten: foods))
    }

    /// Höherer magScore → größerer kcal-Anteil im Shake.
    func testGewichtungNachMagScore() {
        let milch = macheKandidat(name: "Milch", kcalPro100g: 64, magScore: 80, shakeTauglich: true)
        let hafer = macheKandidat(name: "Hafer", kcalPro100g: 370, magScore: 20, shakeTauglich: true)
        let shake = ShakeBuilder.baue(zielKcal: 500, kandidaten: [milch, hafer])!

        let kcalMilch = shake.komponenten.first { $0.name == "Milch" }!.kcal
        let kcalHafer = shake.komponenten.first { $0.name == "Hafer" }!.kcal
        XCTAssertGreaterThan(kcalMilch, kcalHafer)
    }
}
