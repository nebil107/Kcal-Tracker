import Foundation

// Versionierte, Codable-Abbilder der Modelle für den JSON-Export/Import.
// Enums (KochAufwand, Tageszeit) und SlotVorlage sind bereits Codable und werden direkt genutzt.

struct BackupDatei: Codable {
    var version: Int = 1
    var exportiertAm: Date = Date()
    var settings: SettingsDTO?
    var foods: [FoodDTO] = []
    var behaelter: [BehaelterDTO] = []
    var profile: [ProfilDTO] = []
    var logs: [LogDTO] = []
    var dayPlans: [DayPlanDTO] = []
}

struct FoodDTO: Codable {
    var id: UUID
    var name: String
    var kategorie: String
    var kcalPro100g: Double
    var proteinPro100g: Double
    var fettPro100g: Double
    var kohlenhydratePro100g: Double
    var istFestePortion: Bool
    var festeKcal: Double
    var festeProtein: Double
    var festeFett: Double
    var festeKohlenhydrate: Double
    var portionsName: String
    var standardPortion_g: Double
    var magScore: Double
    var nieVorschlagen: Bool
    var tags: [String]
    var kochAufwand: KochAufwand
    var tageszeiten: [Tageszeit]
    var shakeTauglich: Bool

    init(_ f: Food) {
        id = f.id; name = f.name; kategorie = f.kategorie
        kcalPro100g = f.kcalPro100g; proteinPro100g = f.proteinPro100g
        fettPro100g = f.fettPro100g; kohlenhydratePro100g = f.kohlenhydratePro100g
        istFestePortion = f.istFestePortion; festeKcal = f.festeKcal
        festeProtein = f.festeProtein; festeFett = f.festeFett; festeKohlenhydrate = f.festeKohlenhydrate
        portionsName = f.portionsName; standardPortion_g = f.standardPortion_g
        magScore = f.magScore; nieVorschlagen = f.nieVorschlagen; tags = f.tags
        kochAufwand = f.kochAufwand; tageszeiten = f.tageszeiten; shakeTauglich = f.shakeTauglich
    }

    func alsFood() -> Food {
        Food(id: id, name: name, kategorie: kategorie,
             kcalPro100g: kcalPro100g, proteinPro100g: proteinPro100g,
             fettPro100g: fettPro100g, kohlenhydratePro100g: kohlenhydratePro100g,
             istFestePortion: istFestePortion, festeKcal: festeKcal,
             festeProtein: festeProtein, festeFett: festeFett, festeKohlenhydrate: festeKohlenhydrate,
             portionsName: portionsName, standardPortion_g: standardPortion_g,
             magScore: magScore, nieVorschlagen: nieVorschlagen, tags: tags,
             kochAufwand: kochAufwand, tageszeiten: tageszeiten, shakeTauglich: shakeTauglich)
    }
}

struct BehaelterDTO: Codable {
    var id: UUID
    var name: String
    var tara_g: Double

    init(_ b: Behaelter) { id = b.id; name = b.name; tara_g = b.tara_g }
    func alsBehaelter() -> Behaelter { Behaelter(id: id, name: name, tara_g: tara_g) }
}

struct ProfilDTO: Codable {
    var id: UUID
    var name: String
    var aktiv: Bool
    var aufwachStunde: Int
    var aufwachMinute: Int
    var cutoffStunde: Int
    var cutoffMinute: Int
    var slots: [SlotVorlage]

    init(_ p: RoutineProfil) {
        id = p.id; name = p.name; aktiv = p.aktiv
        aufwachStunde = p.aufwachStunde; aufwachMinute = p.aufwachMinute
        cutoffStunde = p.cutoffStunde; cutoffMinute = p.cutoffMinute
        slots = p.slots
    }
    func alsProfil() -> RoutineProfil {
        RoutineProfil(id: id, name: name, aktiv: aktiv,
                      aufwachStunde: aufwachStunde, aufwachMinute: aufwachMinute,
                      cutoffStunde: cutoffStunde, cutoffMinute: cutoffMinute, slots: slots)
    }
}

struct LogDTO: Codable {
    var id: UUID
    var zeitstempel: Date
    var foodId: UUID?
    var foodName: String
    var bruttogewicht_g: Double
    var behaelterId: UUID?
    var tara_g: Double
    var netto_g: Double
    var istFestePortion: Bool
    var portionen: Double
    var kcal: Double
    var protein: Double
    var fett: Double
    var kohlenhydrate: Double
    var tageszeit: Tageszeit

    init(_ l: LogEntry) {
        id = l.id; zeitstempel = l.zeitstempel
        foodId = l.food?.id; foodName = l.foodName
        bruttogewicht_g = l.bruttogewicht_g; behaelterId = l.behaelter?.id
        tara_g = l.tara_g; netto_g = l.netto_g
        istFestePortion = l.istFestePortion; portionen = l.portionen
        kcal = l.kcal; protein = l.protein; fett = l.fett; kohlenhydrate = l.kohlenhydrate
        tageszeit = l.tageszeit
    }

    func alsLog() -> LogEntry {
        LogEntry(id: id, zeitstempel: zeitstempel, foodName: foodName,
                 bruttogewicht_g: bruttogewicht_g, tara_g: tara_g, netto_g: netto_g,
                 istFestePortion: istFestePortion, portionen: portionen,
                 kcal: kcal, protein: protein, fett: fett, kohlenhydrate: kohlenhydrate,
                 tageszeit: tageszeit)
    }
}

struct DayPlanDTO: Codable {
    var id: UUID
    var datum: Date
    var kcalZiel: Double
    var wasserZiel_ml: Double
    var wasserGetrunken_ml: Double

    init(_ d: DayPlan) {
        id = d.id; datum = d.datum; kcalZiel = d.kcalZiel
        wasserZiel_ml = d.wasserZiel_ml; wasserGetrunken_ml = d.wasserGetrunken_ml
    }
    func alsDayPlan() -> DayPlan {
        DayPlan(id: id, datum: datum, kcalZiel: kcalZiel,
                wasserZiel_ml: wasserZiel_ml, wasserGetrunken_ml: wasserGetrunken_ml)
    }
}

struct SettingsDTO: Codable {
    var kcalZiel: Double
    var zielProtein_g: Double
    var zielFett_g: Double
    var zielKohlenhydrate_g: Double
    var proteinProzent: Double
    var fettProzent: Double
    var khProzent: Double
    var makrosAutomatisch: Bool
    var wasserZiel_ml: Double
    var planungsVorliebe: PlanungsVorliebe
    var shakeProTag: Int
    var shakeMindestKcal: Double
    var maxSlotFaktor: Double

    init(_ s: AppSettings) {
        kcalZiel = s.kcalZiel
        zielProtein_g = s.zielProtein_g; zielFett_g = s.zielFett_g; zielKohlenhydrate_g = s.zielKohlenhydrate_g
        proteinProzent = s.proteinProzent; fettProzent = s.fettProzent; khProzent = s.khProzent
        makrosAutomatisch = s.makrosAutomatisch; wasserZiel_ml = s.wasserZiel_ml
        planungsVorliebe = s.planungsVorliebe; shakeProTag = s.shakeProTag
        shakeMindestKcal = s.shakeMindestKcal; maxSlotFaktor = s.maxSlotFaktor
    }

    /// Überträgt die Werte auf eine bestehende Settings-Instanz (es bleibt eine einzige Instanz).
    func anwenden(auf s: AppSettings) {
        s.kcalZiel = kcalZiel
        s.zielProtein_g = zielProtein_g; s.zielFett_g = zielFett_g; s.zielKohlenhydrate_g = zielKohlenhydrate_g
        s.proteinProzent = proteinProzent; s.fettProzent = fettProzent; s.khProzent = khProzent
        s.makrosAutomatisch = makrosAutomatisch; s.wasserZiel_ml = wasserZiel_ml
        s.planungsVorliebe = planungsVorliebe; s.shakeProTag = shakeProTag
        s.shakeMindestKcal = shakeMindestKcal; s.maxSlotFaktor = maxSlotFaktor
    }
}
