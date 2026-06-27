import Foundation

/// Reine, deterministische Planungs-Logik (Herzstück der App). Kein LLM/KI, keine UI, kein SwiftData.
///
/// Ablauf:
/// 1. Plannbare Slots bestimmen (ab „jetzt", bis „cutoff").
/// 2. Shake garantieren (mind. `shakeProTag`) – Shake hat höchste Priorität.
/// 3. Budgets fortlaufend verteilen (`restBudget ÷ restSlots`, gewichtet), mit Shake-Reservierung & Obergrenze.
/// 4. Je Slot den besten Vorschlag wählen (Ranking) bzw. den Shake zusammenstellen.
/// 5. Wächter-Warnungen erzeugen (Rückstand, Ziel unrealistisch, …).
///
/// Ablehnung (`lehneAb`) verteilt flexibel um: gleiche Slot-Größe mit anderem Gericht
/// („wenige große") oder kleiner jetzt + Rest auf spätere Slots („mehrere kleine").
enum PlanningEngine {

    // Interner Arbeits-Slot während der Planung.
    private struct ArbeitsSlot {
        let id: UUID
        let uhrzeit: Uhrzeit
        var gewicht: Double
        let kochenErlaubt: Bool
        var istShake: Bool
        let tageszeit: Tageszeit
        let fensterMinuten: Int
        var budget: Double = 0
        var vorschlag: Vorschlag?
    }

    // MARK: - Öffentliche API

    /// Erstellt einen kompletten Tagesplan.
    static func erstellePlan(kontext: PlanKontext, kandidaten: [FoodKandidat]) -> PlanErgebnis {
        let slots = vorbereiteSlots(kontext)
        return fuelle(arbeitsSlots: slots, kontext: kontext, kandidaten: kandidaten,
                      startIndex: 0, ausschluss: [:])
    }

    /// Reagiert auf eine Ablehnung: das abgelehnte Lebensmittel wird in diesem Slot ausgeschlossen,
    /// und ab diesem Slot wird neu geplant (frühere Slots bleiben unverändert).
    static func lehneAb(slotId: UUID, plan: PlanErgebnis, kontext: PlanKontext, kandidaten: [FoodKandidat]) -> PlanErgebnis {
        var slots = vorbereiteSlots(kontext)
        guard let startIndex = slots.firstIndex(where: { $0.id == slotId }) else {
            return plan // Slot nicht (mehr) plannbar – Plan unverändert lassen.
        }

        // Frühere Slots aus dem bestehenden Plan übernehmen (werden in `fuelle` als fix behandelt).
        for i in 0..<startIndex {
            if let p = plan.slots.first(where: { $0.id == slots[i].id }) {
                slots[i].budget = p.kcalBudget
                slots[i].vorschlag = p.vorschlag
            }
        }

        // „Mehrere kleine": Gewicht des abgelehnten Slots senken → mehr kcal wandern auf spätere Slots.
        if kontext.vorliebe == .mehrereKleine {
            slots[startIndex].gewicht *= 0.55
        }

        // Abgelehntes Lebensmittel in genau diesem Slot ausschließen.
        var ausschluss: [UUID: Set<UUID>] = [:]
        if let abgelehnt = plan.slots.first(where: { $0.id == slotId })?.vorschlag?.foodId {
            ausschluss[slotId] = [abgelehnt]
        }

        return fuelle(arbeitsSlots: slots, kontext: kontext, kandidaten: kandidaten,
                      startIndex: startIndex, ausschluss: ausschluss)
    }

    // MARK: - Slot-Vorbereitung

    private static func vorbereiteSlots(_ kontext: PlanKontext) -> [ArbeitsSlot] {
        // Nur Slots ab jetzt und bis zum Cutoff sind plannbar.
        let plannbar = kontext.slots
            .filter { $0.uhrzeit >= kontext.jetzt && $0.uhrzeit <= kontext.cutoff }
            .sorted { $0.uhrzeit < $1.uhrzeit }

        guard !plannbar.isEmpty else { return [] }

        // Shake garantieren: fehlende Shake-Slots auf den frühesten freien Slots ergänzen.
        var istShake = plannbar.map { $0.istShakeSlot }
        let benoetigt = min(max(0, kontext.shakeProTag), plannbar.count)
        var vorhanden = istShake.filter { $0 }.count
        if vorhanden < benoetigt {
            for i in plannbar.indices where !istShake[i] && vorhanden < benoetigt {
                istShake[i] = true
                vorhanden += 1
            }
        }

        // Zeitfenster je Slot = Abstand zum nächsten Slot bzw. bis zum Cutoff.
        var result: [ArbeitsSlot] = []
        for (i, s) in plannbar.enumerated() {
            let endeMin = (i + 1 < plannbar.count)
                ? plannbar[i + 1].uhrzeit.minutenAbMitternacht
                : kontext.cutoff.minutenAbMitternacht
            let fenster = max(0, endeMin - s.uhrzeit.minutenAbMitternacht)
            result.append(ArbeitsSlot(
                id: s.id, uhrzeit: s.uhrzeit, gewicht: max(0, s.gewicht),
                kochenErlaubt: s.kochenErlaubt, istShake: istShake[i],
                tageszeit: s.tageszeit, fensterMinuten: fenster))
        }
        return result
    }

    // MARK: - Befüllung (Budgetverteilung + Vorschlagswahl)

    private static func fuelle(
        arbeitsSlots: [ArbeitsSlot],
        kontext: PlanKontext,
        kandidaten: [FoodKandidat],
        startIndex: Int,
        ausschluss: [UUID: Set<UUID>]
    ) -> PlanErgebnis {

        var slots = arbeitsSlots
        var warnungen: [Warnung] = []

        guard !slots.isEmpty else {
            let rest = max(0, kontext.kcalZiel - kontext.bereitsGegessenKcal)
            if rest > 0 {
                warnungen.append(Warnung(art: .zielUnrealistisch,
                    text: "Keine plannbaren Slots vor dem Cutoff. Cutoff verschieben oder Slots hinzufügen?"))
            }
            return PlanErgebnis(slots: [], warnungen: warnungen)
        }

        let restKcalGesamt = max(0, kontext.kcalZiel - kontext.bereitsGegessenKcal)

        // Bereits durch frühere (fixe) Slots verplant?
        let bereitsVerplant = slots.prefix(startIndex).reduce(0.0) { $0 + ($1.vorschlag?.kcal ?? 0) }
        var verbleibend = max(0, restKcalGesamt - bereitsVerplant)

        let anzahl = Double(slots.count)
        let fairShare = anzahl > 0 ? restKcalGesamt / anzahl : 0
        let maxProSlot = max(0, kontext.maxSlotFaktor) * fairShare

        var keinShakeMoeglich = false
        var slotGekappt = false

        for i in slots.indices where i >= startIndex {
            let eigenGewicht = max(0, slots[i].gewicht)
            let restGewicht = slots[i...].reduce(0.0) { $0 + max(0, $1.gewicht) }
            let istLetzter = (i == slots.count - 1)

            // Ziel-kcal dieses Slots: fortlaufende Neuverteilung.
            var ziel: Double
            if verbleibend <= 0 {
                ziel = 0
            } else if istLetzter {
                ziel = verbleibend
            } else if restGewicht > 0 {
                ziel = verbleibend * (eigenGewicht / restGewicht)
            } else {
                ziel = verbleibend / Double(slots.count - i) // keine Gewichte → Gleichverteilung
            }

            // Obergrenze je Slot anwenden …
            if maxProSlot > 0, ziel > maxProSlot {
                ziel = maxProSlot
                slotGekappt = true
            }
            // … aber der Shake hat höchste Priorität und bekommt mindestens seinen Mindestwert.
            if slots[i].istShake {
                ziel = max(ziel, min(kontext.shakeMindestKcal, verbleibend))
            }
            ziel = max(0, ziel)
            slots[i].budget = ziel

            let ausgeschlossen = ausschluss[slots[i].id] ?? []

            if slots[i].istShake {
                let shakeKandidaten = kandidaten.filter { !ausgeschlossen.contains($0.id) }
                if ziel > 0, let shake = ShakeBuilder.baue(zielKcal: ziel, kandidaten: shakeKandidaten) {
                    slots[i].vorschlag = Vorschlag(
                        foodId: shake.komponenten.first?.foodId ?? UUID(),
                        name: "Shake", istShake: true, menge_g: nil, portionen: nil,
                        portionsName: nil, kcal: shake.gesamtKcal, makros: shake.gesamtMakros, shake: shake)
                    verbleibend -= shake.gesamtKcal
                } else if ziel > 0 {
                    // Kein Shake möglich → wie ein normaler Slot behandeln.
                    keinShakeMoeglich = true
                    if let v = waehleEinzelFood(ziel: ziel, slot: slots[i], kontext: kontext,
                                                kandidaten: kandidaten, ausgeschlossen: ausgeschlossen) {
                        slots[i].vorschlag = v
                        verbleibend -= v.kcal
                    }
                }
            } else if ziel > 0 {
                if let v = waehleEinzelFood(ziel: ziel, slot: slots[i], kontext: kontext,
                                            kandidaten: kandidaten, ausgeschlossen: ausgeschlossen) {
                    slots[i].vorschlag = v
                    verbleibend -= v.kcal
                } else {
                    warnungen.append(Warnung(art: .keineKandidaten,
                        text: "Für \(slots[i].uhrzeit.anzeige) wurde kein passendes Lebensmittel gefunden."))
                }
            }
        }

        warnungen.append(contentsOf: wächter(
            slots: slots, kontext: kontext, restKcalGesamt: restKcalGesamt,
            verbleibend: verbleibend, keinShakeMoeglich: keinShakeMoeglich, slotGekappt: slotGekappt))

        let ergebnis = slots.map {
            GeplanterSlot(id: $0.id, uhrzeit: $0.uhrzeit, kcalBudget: $0.budget,
                          istShakeSlot: $0.istShake, kochenErlaubt: $0.kochenErlaubt,
                          tageszeit: $0.tageszeit, vorschlag: $0.vorschlag)
        }
        return PlanErgebnis(slots: ergebnis, warnungen: warnungen)
    }

    // MARK: - Vorschlagswahl & Ranking

    private static func waehleEinzelFood(
        ziel: Double, slot: ArbeitsSlot, kontext: PlanKontext,
        kandidaten: [FoodKandidat], ausgeschlossen: Set<UUID>
    ) -> Vorschlag? {
        let verfuegbar = kandidaten.filter { !$0.nieVorschlagen && !ausgeschlossen.contains($0.id) }
        guard !verfuegbar.isEmpty else { return nil }

        let best = verfuegbar.max { a, b in
            ranking(food: a, slot: slot, ziel: ziel) < ranking(food: b, slot: slot, ziel: ziel)
        }
        guard let food = best else { return nil }
        return baueVorschlag(food: food, ziel: ziel)
    }

    /// Ranking = magScore × VarietyPenalty × FitWert × Tageszeit-Match × Kochaufwand-Match.
    static func ranking(food: FoodKandidat, slot: GeplanterSlotKontext, ziel: Double) -> Double {
        let mag = max(0.01, food.magScore / 50.0) // Default magScore 50 → Faktor 1.0
        let variety = varietyPenalty(food)
        let fit = fitWert(food: food, ziel: ziel)
        let zeit = tageszeitMatch(food: food, slotTageszeit: slot.tageszeit)
        let koch = kochMatch(food: food, kochenErlaubt: slot.kochenErlaubt, fensterMinuten: slot.fensterMinuten)
        return mag * variety * fit * zeit * koch
    }

    private static func ranking(food: FoodKandidat, slot: ArbeitsSlot, ziel: Double) -> Double {
        ranking(food: food,
                slot: GeplanterSlotKontext(tageszeit: slot.tageszeit,
                                           kochenErlaubt: slot.kochenErlaubt,
                                           fensterMinuten: slot.fensterMinuten),
                ziel: ziel)
    }

    /// Schlanker Kontext für das Ranking (auch von außen/Tests nutzbar).
    struct GeplanterSlotKontext {
        var tageszeit: Tageszeit
        var kochenErlaubt: Bool
        var fensterMinuten: Int
    }

    private static func varietyPenalty(_ food: FoodKandidat) -> Double {
        guard let tage = food.zuletztGegessenVorTagen else { return 1.0 }
        // Heute gegessen (0 Tage) → 0,3 ; ab 3 Tagen → 1,0.
        let v = 0.3 + 0.7 * min(1.0, max(0, tage) / 3.0)
        return min(1.0, max(0.3, v))
    }

    private static func fitWert(food: FoodKandidat, ziel: Double) -> Double {
        guard ziel > 0 else { return 0.5 }
        if food.istFestePortion {
            let proPortion = food.festeKcal > 0 ? food.festeKcal : ziel
            let gerundet = max(1, (ziel / proPortion).rounded())
            let erreicht = proPortion * gerundet
            let abweichung = abs(erreicht - ziel) / ziel
            return max(0.1, 1.0 - min(1.0, abweichung))
        } else {
            guard food.kcalProGramm > 0 else { return 0.1 }
            let benoetigt = ziel / food.kcalProGramm
            let standard = food.standardPortion_g > 0 ? food.standardPortion_g : benoetigt
            let verhaeltnis = benoetigt / standard
            // Glockenkurve um Verhältnis 1 (log-normal): nahe Standardportion = bester Fit.
            let lnv = log(max(0.0001, verhaeltnis))
            let sigma = 0.9
            let w = exp(-(lnv * lnv) / (2 * sigma * sigma))
            return min(1.0, max(0.1, w))
        }
    }

    private static func tageszeitMatch(food: FoodKandidat, slotTageszeit: Tageszeit) -> Double {
        if food.tageszeiten.isEmpty { return 1.0 }
        if food.tageszeiten.contains(.egal) { return 1.0 }
        if slotTageszeit == .egal { return 1.0 }
        return food.tageszeiten.contains(slotTageszeit) ? 1.0 : 0.5
    }

    private static func kochMatch(food: FoodKandidat, kochenErlaubt: Bool, fensterMinuten: Int) -> Double {
        if food.kochAufwand == .keiner { return 1.0 }   // No-Cook passt immer
        if !kochenErlaubt { return 0.05 }               // Kochen nicht erlaubt → quasi ausschließen
        // Kochen erlaubt: reicht das Zeitfenster?
        return fensterMinuten >= food.kochAufwand.geschaetzteMinuten ? 1.0 : 0.2
    }

    private static func baueVorschlag(food: FoodKandidat, ziel: Double) -> Vorschlag {
        if food.istFestePortion {
            let proPortion = food.festeKcal > 0 ? food.festeKcal : 1
            let portionen = max(1, (ziel / proPortion).rounded())
            return Vorschlag(
                foodId: food.id, name: food.name, istShake: false,
                menge_g: nil, portionen: portionen, portionsName: food.portionsName,
                kcal: food.festeKcal * portionen, makros: food.festeMakros * portionen, shake: nil)
        } else {
            let kcalProGramm = food.kcalProGramm
            let menge = kcalProGramm > 0 ? ziel / kcalProGramm : food.standardPortion_g
            return Vorschlag(
                foodId: food.id, name: food.name, istShake: false,
                menge_g: menge, portionen: nil, portionsName: nil,
                kcal: kcalProGramm * menge, makros: food.makrosProGramm * menge, shake: nil)
        }
    }

    // MARK: - Wächter / Warnungen

    private static func wächter(
        slots: [ArbeitsSlot], kontext: PlanKontext, restKcalGesamt: Double,
        verbleibend: Double, keinShakeMoeglich: Bool, slotGekappt: Bool
    ) -> [Warnung] {
        var w: [Warnung] = []

        if keinShakeMoeglich {
            w.append(Warnung(art: .keinShakeMoeglich,
                text: "Kein Shake möglich – markiere passende Lebensmittel als „shake-tauglich"."))
        }

        // Ziel nicht erreichbar: nennenswerter Rest bleibt unverplant.
        if verbleibend > max(100, restKcalGesamt * 0.05) {
            w.append(Warnung(art: .zielUnrealistisch,
                text: "Es bleiben \(Format.kcal(verbleibend)) übrig. Cutoff verschieben oder einen Notfall-Snack einplanen?"))
        } else if slotGekappt {
            w.append(Warnung(art: .slotUebervoll,
                text: "Einzelne Slots sind an der Obergrenze. Für mehr Spielraum weitere Slots oder Zeit einplanen."))
        }

        // Rückstand: die verbleibenden Slots müssen deutlich mehr tragen als ein „fairer" Slot des ganzen Tages.
        let alleSlots = max(1, kontext.slots.count)
        let komfortProSlot = kontext.kcalZiel / Double(alleSlots)
        let plannbar = max(1, slots.count)
        let proPlannbar = restKcalGesamt / Double(plannbar)
        if plannbar < alleSlots, proPlannbar > komfortProSlot * 1.5 {
            w.append(Warnung(art: .rueckstand,
                text: "Du liegst zurück – die nächsten Portionen fallen größer aus (\(Format.kcal(proPlannbar)) je Slot)."))
        }

        return w
    }
}
