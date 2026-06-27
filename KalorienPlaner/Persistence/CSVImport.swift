import Foundation
import SwiftData

/// Import einer Lebensmittel-Liste aus einer CSV-Datei (z. B. aus Excel/Google Sheets exportiert).
///
/// Tolerant gebaut:
/// - Trennzeichen `;` (deutsches Excel) oder `,` wird automatisch erkannt.
/// - Dezimal-Komma oder -Punkt werden beide verstanden.
/// - Spalten werden über die Kopfzeile zugeordnet; fehlende Spalten/leere Zellen ändern nichts
///   (für neue Einträge gelten Standardwerte).
/// - „Upsert" per Name: existiert ein Lebensmittel mit gleichem Namen, wird es aktualisiert,
///   sonst neu angelegt. (magScore/Lernen bleibt dabei erhalten.)
enum CSVImport {

    struct Ergebnis {
        var hinzugefuegt = 0
        var aktualisiert = 0
        var uebersprungen = 0
        var fehler: [String] = []

        var zusammenfassung: String {
            if let erster = fehler.first { return erster }
            return "Importiert: \(hinzugefuegt) neu, \(aktualisiert) aktualisiert"
                + (uebersprungen > 0 ? ", \(uebersprungen) übersprungen." : ".")
        }
    }

    static func importiere(text rohtext: String, context: ModelContext) -> Ergebnis {
        var text = rohtext
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() } // BOM entfernen

        var zeilen = parse(text)
        guard !zeilen.isEmpty else { return Ergebnis(fehler: ["Die Datei ist leer."]) }

        let header = zeilen.removeFirst().map(norm)
        func spalte(_ namen: [String]) -> Int? {
            for n in namen { if let i = header.firstIndex(of: n) { return i } }
            return nil
        }

        let iName = spalte(["name", "lebensmittel"])
        guard let iName else {
            return Ergebnis(fehler: ["Es fehlt eine Spalte „name" in der Kopfzeile."])
        }
        let iKategorie = spalte(["kategorie", "category"])
        let iKcal = spalte(["kcal", "kalorien", "energie", "kcalpro100g", "kcal100g"])
        let iProtein = spalte(["protein", "eiweiss", "proteinpro100g", "eiweisspro100g"])
        let iFett = spalte(["fett", "fettpro100g"])
        let iKh = spalte(["kohlenhydrate", "kh", "carbs", "kohlenhydratepro100g", "kohlenhydrate100g"])
        let iFest = spalte(["festeportion", "fest", "festportion"])
        let iPortionsname = spalte(["portionsname", "portion", "portionname"])
        let iStandard = spalte(["standardportion", "standardportiong", "portionsgewicht"])
        let iShake = spalte(["shake", "shaketauglich"])
        let iKoch = spalte(["kochaufwand", "aufwand"])
        let iTageszeiten = spalte(["tageszeiten", "tageszeit"])
        let iTags = spalte(["tags", "schlagworte"])

        // Bestehende Lebensmittel nach Name (für Upsert).
        var nachName: [String: Food] = [:]
        for f in (try? context.fetch(FetchDescriptor<Food>())) ?? [] {
            nachName[f.name.lowercased()] = f
        }

        var erg = Ergebnis()

        for row in zeilen {
            func zelle(_ i: Int?) -> String {
                guard let i, i < row.count else { return "" }
                return row[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let name = zelle(iName)
            if name.isEmpty { erg.uebersprungen += 1; continue }

            let food: Food
            let istNeu: Bool
            if let vorhanden = nachName[name.lowercased()] {
                food = vorhanden; istNeu = false
            } else {
                food = Food(); food.name = name; istNeu = true
            }

            befuelle(food, name: name, kategorie: zelle(iKategorie),
                     kcal: zelle(iKcal), protein: zelle(iProtein), fett: zelle(iFett), kh: zelle(iKh),
                     fest: zelle(iFest), portionsname: zelle(iPortionsname), standard: zelle(iStandard),
                     shake: zelle(iShake), koch: zelle(iKoch), tageszeiten: zelle(iTageszeiten), tags: zelle(iTags),
                     hatFestSpalte: iFest != nil)

            if istNeu {
                context.insert(food)
                nachName[name.lowercased()] = food
                erg.hinzugefuegt += 1
            } else {
                erg.aktualisiert += 1
            }
        }

        try? context.save()
        return erg
    }

    // MARK: - Befüllung einer Food-Zeile

    private static func befuelle(
        _ food: Food, name: String, kategorie: String,
        kcal: String, protein: String, fett: String, kh: String,
        fest: String, portionsname: String, standard: String,
        shake: String, koch: String, tageszeiten: String, tags: String,
        hatFestSpalte: Bool
    ) {
        food.name = name
        if !kategorie.isEmpty { food.kategorie = kategorie }

        // Feste Portion (nur ändern, wenn Spalte vorhanden & Zelle gefüllt).
        if hatFestSpalte, let b = boolWert(fest) { food.istFestePortion = b }
        let istFest = food.istFestePortion

        if let v = zahl(kcal) { if istFest { food.festeKcal = v } else { food.kcalPro100g = v } }
        if let v = zahl(protein) { if istFest { food.festeProtein = v } else { food.proteinPro100g = v } }
        if let v = zahl(fett) { if istFest { food.festeFett = v } else { food.fettPro100g = v } }
        if let v = zahl(kh) { if istFest { food.festeKohlenhydrate = v } else { food.kohlenhydratePro100g = v } }

        if !portionsname.isEmpty { food.portionsName = portionsname }
        if let v = zahl(standard) { food.standardPortion_g = v }
        if let b = boolWert(shake) { food.shakeTauglich = b }
        if let a = kochAufwandWert(koch) { food.kochAufwand = a }
        if !tageszeiten.isEmpty { food.tageszeiten = tageszeitenWert(tageszeiten) }
        if !tags.isEmpty { food.tags = tagsWert(tags) }
    }

    // MARK: - CSV-Parser (mit Anführungszeichen & \r\n)

    static func parse(_ text: String) -> [[String]] {
        // Trennzeichen aus der ersten Zeile ableiten (`;` bevorzugt, sonst `,`).
        let ersteZeile = text.prefix { $0 != "\n" && $0 != "\r" }
        let delim: Character = ersteZeile.contains(";") ? ";" : ","

        var rows: [[String]] = []
        var row: [String] = []
        var feld = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { feld.append("\""); i += 2; continue }
                    inQuotes = false; i += 1; continue
                }
                feld.append(c); i += 1
            } else {
                if c == "\"" { inQuotes = true; i += 1; continue }
                if c == delim { row.append(feld); feld = ""; i += 1; continue }
                if c == "\n" || c == "\r" {
                    if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
                    row.append(feld); feld = ""
                    if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
                    row = []; i += 1; continue
                }
                feld.append(c); i += 1
            }
        }
        if !feld.isEmpty || !row.isEmpty {
            row.append(feld)
            if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
        }
        return rows
    }

    // MARK: - Wert-Parser

    private static func norm(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "ß", with: "ss")
            .components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }

    private static func zahl(_ s: String) -> Double? {
        let bereinigt = s.replacingOccurrences(of: ",", with: ".")
            .filter { "0123456789.-".contains($0) }
        guard !bereinigt.isEmpty else { return nil }
        return Double(bereinigt)
    }

    private static func boolWert(_ s: String) -> Bool? {
        let n = norm(s)
        if n.isEmpty { return nil }
        if ["ja", "yes", "true", "wahr", "1", "x"].contains(n) { return true }
        if ["nein", "no", "false", "falsch", "0"].contains(n) { return false }
        return nil
    }

    private static func kochAufwandWert(_ s: String) -> KochAufwand? {
        let n = norm(s)
        if n.isEmpty { return nil }
        if n.hasPrefix("kein") || n == "nocook" || n == "no" { return .keiner }
        if n.hasPrefix("wenig") || n == "gering" || n == "low" { return .wenig }
        if n.hasPrefix("mittel") || n == "medium" { return .mittel }
        if n.hasPrefix("hoch") || n == "high" || n == "viel" { return .hoch }
        return nil
    }

    private static func tageszeitenWert(_ s: String) -> [Tageszeit] {
        let tokens = s.components(separatedBy: CharacterSet(charactersIn: "|/;,"))
        var result: [Tageszeit] = []
        for t in tokens {
            let n = norm(t)
            if n.isEmpty { continue }
            if n.hasPrefix("frueh") || n.hasPrefix("morgen") || n == "breakfast" { result.append(.fruehstueck) }
            else if n.hasPrefix("mittag") || n == "lunch" { result.append(.mittag) }
            else if n.hasPrefix("abend") || n == "dinner" { result.append(.abend) }
            else if n.hasPrefix("snack") || n == "zwischenmahlzeit" { result.append(.snack) }
            else if n.hasPrefix("egal") || n == "any" || n == "alle" { result.append(.egal) }
        }
        return result.isEmpty ? [.egal] : Array(Set(result))
    }

    private static func tagsWert(_ s: String) -> [String] {
        s.components(separatedBy: CharacterSet(charactersIn: "|;,"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Export

    /// Erzeugt eine CSV-Datei (Trennzeichen `;`, deutsches Dezimalkomma) aus den Lebensmitteln.
    /// Das Format passt 1:1 zum Import – exportieren, in Excel anpassen, wieder importieren.
    static func exportiere(foods: [Food]) -> String {
        let kopf = ["name", "kategorie", "kcal", "protein", "fett", "kohlenhydrate",
                    "feste_portion", "portionsname", "standardportion_g", "shake",
                    "kochaufwand", "tageszeiten", "tags"]
        var zeilen = [kopf.joined(separator: ";")]

        let sortiert = foods.sorted {
            $0.kategorie == $1.kategorie ? $0.name < $1.name : $0.kategorie < $1.kategorie
        }
        for f in sortiert {
            let kcal = f.istFestePortion ? f.festeKcal : f.kcalPro100g
            let protein = f.istFestePortion ? f.festeProtein : f.proteinPro100g
            let fett = f.istFestePortion ? f.festeFett : f.fettPro100g
            let kh = f.istFestePortion ? f.festeKohlenhydrate : f.kohlenhydratePro100g
            let felder = [
                f.name, f.kategorie, formatiere(kcal), formatiere(protein), formatiere(fett), formatiere(kh),
                f.istFestePortion ? "ja" : "nein", f.portionsName, formatiere(f.standardPortion_g),
                f.shakeTauglich ? "ja" : "nein", f.kochAufwand.rawValue,
                f.tageszeiten.map { $0.rawValue }.joined(separator: "|"),
                f.tags.joined(separator: "|")
            ]
            zeilen.append(felder.map(maskiere).joined(separator: ";"))
        }
        return zeilen.joined(separator: "\r\n")
    }

    private static let zahlFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 3
        return f
    }()

    private static func formatiere(_ wert: Double) -> String {
        zahlFormatter.string(from: NSNumber(value: wert)) ?? "0"
    }

    /// CSV-sicheres Maskieren (Anführungszeichen, wenn `;`, `"` oder Zeilenumbruch enthalten ist).
    private static func maskiere(_ feld: String) -> String {
        if feld.contains(";") || feld.contains("\"") || feld.contains("\n") || feld.contains("\r") {
            return "\"" + feld.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return feld
    }
}
