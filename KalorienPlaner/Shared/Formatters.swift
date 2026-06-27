import Foundation

/// Deutsche Formatierung für Zahlen, Gewichte, Energie und Uhrzeiten.
/// Gebündelt, damit die Darstellung in der ganzen App einheitlich ist.
enum Format {

    private static let deLocale = Locale(identifier: "de_DE")

    /// Ganze kcal, z. B. „1.234 kcal".
    static func kcal(_ wert: Double) -> String {
        "\(ganzzahl(wert)) kcal"
    }

    /// Gramm mit einer Nachkommastelle bei Bedarf, z. B. „250 g" oder „37,5 g".
    static func gramm(_ wert: Double) -> String {
        "\(dezimal(wert, maxNachkomma: 1)) g"
    }

    /// Milliliter, z. B. „1.500 ml".
    static func milliliter(_ wert: Double) -> String {
        "\(ganzzahl(wert)) ml"
    }

    /// Liter-Darstellung für Wasser, z. B. „1,5 L".
    static func liter(ausMilliliter ml: Double) -> String {
        "\(dezimal(ml / 1000, maxNachkomma: 2)) L"
    }

    /// Ganze Zahl mit Tausenderpunkt (deutsch).
    static func ganzzahl(_ wert: Double) -> String {
        let f = NumberFormatter()
        f.locale = deLocale
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: wert.rounded())) ?? "0"
    }

    /// Dezimalzahl mit konfigurierbaren Nachkommastellen (deutsch, Komma).
    static func dezimal(_ wert: Double, maxNachkomma: Int) -> String {
        let f = NumberFormatter()
        f.locale = deLocale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = maxNachkomma
        return f.string(from: NSNumber(value: wert)) ?? "0"
    }

    /// Prozent, z. B. „45 %".
    static func prozent(_ anteil0bis1: Double) -> String {
        "\(ganzzahl(anteil0bis1 * 100)) %"
    }
}
