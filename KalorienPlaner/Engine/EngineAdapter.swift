import Foundation

/// Brücke zwischen den SwiftData-Modellen und den reinen Engine-Werttypen.
/// Hält die Engine frei von SwiftData – nur hier wird umgewandelt.
enum EngineAdapter {

    /// Wandelt ein `Food` in einen Engine-Kandidaten um.
    static func kandidat(aus food: Food, zuletztGegessenVorTagen: Double?) -> FoodKandidat {
        FoodKandidat(
            id: food.id,
            name: food.name,
            kategorie: food.kategorie,
            kcalPro100g: food.kcalPro100g,
            proteinPro100g: food.proteinPro100g,
            fettPro100g: food.fettPro100g,
            kohlenhydratePro100g: food.kohlenhydratePro100g,
            istFestePortion: food.istFestePortion,
            festeKcal: food.festeKcal,
            festeMakros: food.festeMakros,
            portionsName: food.portionsName,
            standardPortion_g: food.standardPortion_g,
            magScore: food.magScore,
            nieVorschlagen: food.nieVorschlagen,
            kochAufwand: food.kochAufwand,
            tageszeiten: food.tageszeiten,
            shakeTauglich: food.shakeTauglich,
            zuletztGegessenVorTagen: zuletztGegessenVorTagen)
    }

    /// Erzeugt Kandidaten und berechnet aus den LogEntries, wie viele Tage der letzte Verzehr her ist
    /// (für die VarietyPenalty der Engine).
    static func kandidaten(aus foods: [Food], logs: [LogEntry],
                           jetzt: Date = Date(), kalender: Calendar = .current) -> [FoodKandidat] {
        var letzterVerzehr: [UUID: Date] = [:]
        for log in logs {
            guard let fid = log.food?.id else { continue }
            if let vorhanden = letzterVerzehr[fid] {
                if log.zeitstempel > vorhanden { letzterVerzehr[fid] = log.zeitstempel }
            } else {
                letzterVerzehr[fid] = log.zeitstempel
            }
        }
        return foods.map { food in
            var tage: Double?
            if let datum = letzterVerzehr[food.id] {
                tage = max(0, jetzt.timeIntervalSince(datum) / 86_400.0)
            }
            return kandidat(aus: food, zuletztGegessenVorTagen: tage)
        }
    }

    /// Wandelt die SlotVorlagen eines RoutineProfils in Engine-Slots um.
    static func slotEingaben(aus profil: RoutineProfil) -> [SlotEingabe] {
        profil.slots.map {
            SlotEingabe(id: $0.id, uhrzeit: $0.uhrzeit, gewicht: $0.gewichtProzent,
                        kochenErlaubt: $0.kochenErlaubt, istShakeSlot: $0.istShakeSlot,
                        tageszeit: $0.tageszeit)
        }
    }

    /// Baut den vollständigen Planungskontext aus Einstellungen und aktivem Profil.
    static func planKontext(settings: AppSettings, profil: RoutineProfil,
                            jetzt: Uhrzeit, bereitsGegessenKcal: Double) -> PlanKontext {
        PlanKontext(
            kcalZiel: settings.kcalZiel,
            makroZiel: settings.makroZiel,
            slots: slotEingaben(aus: profil),
            cutoff: profil.cutoff,
            jetzt: jetzt,
            vorliebe: settings.planungsVorliebe,
            shakeProTag: settings.shakeProTag,
            bereitsGegessenKcal: bereitsGegessenKcal,
            shakeMindestKcal: settings.shakeMindestKcal,
            maxSlotFaktor: settings.maxSlotFaktor)
    }
}
