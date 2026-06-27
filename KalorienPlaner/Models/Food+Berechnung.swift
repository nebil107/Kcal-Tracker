import Foundation

/// Bequeme Nährwert-Berechnung direkt auf einem `Food`. Delegiert an den reinen
/// `NutritionCalculator`, damit die UI nicht selbst rechnen muss.
extension Food {

    /// Nährwerte für eine variable Netto-Menge (Gramm).
    func naehrwerte(netto_g: Double) -> Naehrwerte {
        NutritionCalculator.naehrwerte(
            netto_g: netto_g,
            kcalPro100g: kcalPro100g,
            proteinPro100g: proteinPro100g,
            fettPro100g: fettPro100g,
            khPro100g: kohlenhydratePro100g)
    }

    /// Nährwerte für eine Anzahl fester Portionen.
    func naehrwerteFest(portionen: Double) -> Naehrwerte {
        NutritionCalculator.naehrwerteFestePortion(
            portionen: portionen,
            festeKcal: festeKcal,
            festeProtein: festeProtein,
            festeFett: festeFett,
            festeKh: festeKohlenhydrate)
    }

    var festeMakros: Makros {
        Makros(protein: festeProtein, fett: festeFett, kohlenhydrate: festeKohlenhydrate)
    }
}
