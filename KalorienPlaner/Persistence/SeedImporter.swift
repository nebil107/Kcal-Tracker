import Foundation
import SwiftData

// MARK: - Seed-Datenstrukturen (tolerant gegenüber fehlenden Feldern)

/// Wurzel der seed.json.
struct SeedDaten: Decodable {
    var version: Int = 1
    var foods: [SeedFood] = []
    var behaelter: [SeedBehaelter] = []
    var routineProfile: [SeedProfil] = []

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 1
        foods = (try? c.decode([SeedFood].self, forKey: .foods)) ?? []
        behaelter = (try? c.decode([SeedBehaelter].self, forKey: .behaelter)) ?? []
        routineProfile = (try? c.decode([SeedProfil].self, forKey: .routineProfile)) ?? []
    }
    enum CodingKeys: String, CodingKey { case version, foods, behaelter, routineProfile }
}

struct SeedFood: Decodable {
    var name = ""
    var kategorie = "Allgemein"
    var kcalPro100g = 0.0
    var proteinPro100g = 0.0
    var fettPro100g = 0.0
    var kohlenhydratePro100g = 0.0
    var istFestePortion = false
    var festeKcal = 0.0
    var festeProtein = 0.0
    var festeFett = 0.0
    var festeKohlenhydrate = 0.0
    var portionsName = "Portion"
    var standardPortion_g = 100.0
    var magScore = 50.0
    var kochAufwand = "keiner"
    var tageszeiten: [String] = ["egal"]
    var shakeTauglich = false
    var tags: [String] = []

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func d(_ key: CodingKeys, _ fallback: Double) -> Double { (try? c.decode(Double.self, forKey: key)) ?? fallback }
        func s(_ key: CodingKeys, _ fallback: String) -> String { (try? c.decode(String.self, forKey: key)) ?? fallback }
        func b(_ key: CodingKeys, _ fallback: Bool) -> Bool { (try? c.decode(Bool.self, forKey: key)) ?? fallback }
        name = s(.name, "")
        kategorie = s(.kategorie, "Allgemein")
        kcalPro100g = d(.kcalPro100g, 0)
        proteinPro100g = d(.proteinPro100g, 0)
        fettPro100g = d(.fettPro100g, 0)
        kohlenhydratePro100g = d(.kohlenhydratePro100g, 0)
        istFestePortion = b(.istFestePortion, false)
        festeKcal = d(.festeKcal, 0)
        festeProtein = d(.festeProtein, 0)
        festeFett = d(.festeFett, 0)
        festeKohlenhydrate = d(.festeKohlenhydrate, 0)
        portionsName = s(.portionsName, "Portion")
        standardPortion_g = d(.standardPortion_g, 100)
        magScore = d(.magScore, 50)
        kochAufwand = s(.kochAufwand, "keiner")
        tageszeiten = (try? c.decode([String].self, forKey: .tageszeiten)) ?? ["egal"]
        shakeTauglich = b(.shakeTauglich, false)
        tags = (try? c.decode([String].self, forKey: .tags)) ?? []
    }
    enum CodingKeys: String, CodingKey {
        case name, kategorie, kcalPro100g, proteinPro100g, fettPro100g, kohlenhydratePro100g
        case istFestePortion, festeKcal, festeProtein, festeFett, festeKohlenhydrate
        case portionsName, standardPortion_g, magScore, kochAufwand, tageszeiten, shakeTauglich, tags
    }

    var tageszeitenGeparst: [Tageszeit] {
        let arr = tageszeiten.compactMap { Tageszeit(rawValue: $0) }
        return arr.isEmpty ? [.egal] : arr
    }

    func alsFood() -> Food {
        Food(
            name: name, kategorie: kategorie,
            kcalPro100g: kcalPro100g, proteinPro100g: proteinPro100g,
            fettPro100g: fettPro100g, kohlenhydratePro100g: kohlenhydratePro100g,
            istFestePortion: istFestePortion, festeKcal: festeKcal,
            festeProtein: festeProtein, festeFett: festeFett, festeKohlenhydrate: festeKohlenhydrate,
            portionsName: portionsName, standardPortion_g: standardPortion_g,
            magScore: magScore, nieVorschlagen: false, tags: tags,
            kochAufwand: KochAufwand(rawValue: kochAufwand) ?? .keiner,
            tageszeiten: tageszeitenGeparst, shakeTauglich: shakeTauglich)
    }
}

struct SeedBehaelter: Decodable {
    var name = ""
    var tara_g = 0.0
}

struct SeedProfil: Decodable {
    var name = ""
    var aktiv = false
    var aufwachStunde = 7
    var aufwachMinute = 0
    var cutoffStunde = 21
    var cutoffMinute = 0
    var slots: [SeedSlot] = []

    func alsProfil() -> RoutineProfil {
        RoutineProfil(
            name: name, aktiv: aktiv,
            aufwachStunde: aufwachStunde, aufwachMinute: aufwachMinute,
            cutoffStunde: cutoffStunde, cutoffMinute: cutoffMinute,
            slots: slots.map { $0.alsVorlage() })
    }
}

struct SeedSlot: Decodable {
    var stunde = 12
    var minute = 0
    var gewichtProzent = 25.0
    var kochenErlaubt = true
    var istShakeSlot = false
    var tageszeit = "egal"

    func alsVorlage() -> SlotVorlage {
        SlotVorlage(stunde: stunde, minute: minute, gewichtProzent: gewichtProzent,
                    kochenErlaubt: kochenErlaubt, istShakeSlot: istShakeSlot,
                    tageszeit: Tageszeit(rawValue: tageszeit) ?? .egal)
    }
}

// MARK: - Importer / Erste Einrichtung

enum SeedImporter {

    /// Stellt sicher, dass genau eine `AppSettings`-Instanz existiert und importiert beim
    /// allerersten Start die seed.json (Lebensmittel, Behälter, Routine-Profile).
    /// Idempotent: läuft pro Installation nur einmal (Flag `seedImportiert`).
    @discardableResult
    static func ersteEinrichtung(context: ModelContext) -> AppSettings {
        let settings: AppSettings
        if let vorhanden = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first {
            settings = vorhanden
        } else {
            let neu = AppSettings()
            neu.makrosAusKcalNeuBerechnen()
            context.insert(neu)
            settings = neu
        }

        guard !settings.seedImportiert else { return settings }

        if let url = Bundle.main.url(forResource: "seed", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let seed = try? JSONDecoder().decode(SeedDaten.self, from: data) {
            seed.foods.forEach { context.insert($0.alsFood()) }
            seed.behaelter.forEach { context.insert(Behaelter(name: $0.name, tara_g: $0.tara_g)) }
            seed.routineProfile.forEach { context.insert($0.alsProfil()) }
        }

        settings.seedImportiert = true
        try? context.save()
        return settings
    }
}
