import Foundation

/// Stellt aus shake-tauglichen Lebensmitteln einen Shake zusammen, der möglichst genau
/// das vorgegebene kcal-Ziel trifft. Gewichtet nach `magScore`. Vollständig deterministisch
/// (keine Zufallswerte), damit das Verhalten testbar ist.
enum ShakeBuilder {

    /// - Parameters:
    ///   - zielKcal: gewünschte Gesamt-kcal des Shakes.
    ///   - kandidaten: alle Lebensmittel; gefiltert wird auf `shakeTauglich` & gültige Energie.
    ///   - maxKomponenten: wie viele Zutaten der Shake maximal enthält.
    /// - Returns: ein `ShakeVorschlag` oder `nil`, wenn keine geeigneten Zutaten existieren.
    static func baue(zielKcal: Double, kandidaten alle: [FoodKandidat], maxKomponenten: Int = 3) -> ShakeVorschlag? {
        let taugliche = alle.filter { $0.shakeTauglich && !$0.nieVorschlagen && $0.kcalProGramm > 0 }
        guard !taugliche.isEmpty, zielKcal > 0 else { return nil }

        // Nach magScore absteigend; bei Gleichstand nach Name (stabile, deterministische Reihenfolge).
        let sortiert = taugliche.sorted {
            $0.magScore != $1.magScore ? $0.magScore > $1.magScore : $0.name < $1.name
        }
        let ausgewaehlt = Array(sortiert.prefix(max(1, maxKomponenten)))

        // kcal anteilig nach magScore auf die Komponenten verteilen.
        let summeScore = ausgewaehlt.reduce(0.0) { $0 + max(1, $1.magScore) }

        var komponenten: [ShakeKomponente] = []
        var gesamtKcal = 0.0
        var gesamtMakros = Makros.null

        for k in ausgewaehlt {
            let anteil = max(1, k.magScore) / summeScore
            let kcalAnteil = zielKcal * anteil
            let menge = kcalAnteil / k.kcalProGramm          // kcalProGramm > 0 (gefiltert)
            let makros = k.makrosProGramm * menge
            let kcal = k.kcalProGramm * menge
            komponenten.append(ShakeKomponente(foodId: k.id, name: k.name, menge_g: menge, kcal: kcal, makros: makros))
            gesamtKcal += kcal
            gesamtMakros = gesamtMakros + makros
        }

        return ShakeVorschlag(komponenten: komponenten, gesamtKcal: gesamtKcal, gesamtMakros: gesamtMakros)
    }

    /// Lesbare Beschreibung der Zusammensetzung, z. B. „250 g Milch + 30 g Haferflocken“.
    static func beschreibung(_ shake: ShakeVorschlag) -> String {
        shake.komponenten
            .map { "\(Format.gramm($0.menge_g)) \($0.name)" }
            .joined(separator: " + ")
    }
}
