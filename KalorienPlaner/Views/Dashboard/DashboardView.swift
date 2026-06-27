import SwiftUI
import SwiftData

/// Tagesübersicht: kcal-Ring, Makro-Balken, Wasser, Restbudget und die heutigen Einträge.
struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppZustand.self) private var zustand

    @Query private var settingsListe: [AppSettings]
    @Query private var heuteLogs: [LogEntry]
    @Query private var heuteDayPlans: [DayPlan]
    @Query private var profile: [RoutineProfil]

    @State private var zeigeEingabe = false
    @State private var zeigeZiele = false

    init() {
        let start = Calendar.current.startOfDay(for: Date())
        let ende = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _heuteLogs = Query(filter: #Predicate<LogEntry> { $0.zeitstempel >= start && $0.zeitstempel < ende },
                           sort: \LogEntry.zeitstempel, order: .reverse)
        _heuteDayPlans = Query(filter: #Predicate<DayPlan> { $0.datum == start }, sort: \DayPlan.datum)
    }

    private var settings: AppSettings? { settingsListe.first }
    private var gegessen: Double { heuteLogs.reduce(0) { $0 + $1.kcal } }
    private var gegessenMakros: Makros { heuteLogs.reduce(Makros.null) { $0 + $1.makros } }
    private var wasserStand: Double { heuteDayPlans.first?.wasserGetrunken_ml ?? 0 }
    private var aktivesProfil: RoutineProfil? { profile.first { $0.aktiv } ?? profile.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let settings {
                    VStack(spacing: Theme.Abstand.gross) {
                        KcalRingView(gegessen: gegessen, ziel: settings.kcalZiel)
                        karte { MacroBarsView(makros: gegessenMakros, ziel: settings.makroZiel) }
                        karte { WasserView(getrunken: wasserStand, ziel: settings.wasserZiel_ml, hinzufuegen: wasserHinzufuegen) }
                        karte { restBudget(settings) }
                        karte { logListe() }
                    }
                    .padding()
                } else {
                    ProgressView().padding(.top, 80)
                }
            }
            .navigationTitle("Heute")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { zeigeEingabe = true } label: { Label("Eintragen", systemImage: "plus.circle.fill") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { zeigeZiele = true } label: { Image(systemName: "slider.horizontal.3") }
                }
            }
            .sheet(isPresented: $zeigeEingabe) { LogEntryView() }
            .sheet(isPresented: $zeigeZiele) {
                if let settings { ZieleBearbeitenView(settings: settings) }
            }
        }
    }

    // MARK: - Bausteine

    @ViewBuilder
    private func karte<Inhalt: View>(@ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        inhalt()
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.kartenHintergrund)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Abstand.eckenradius))
    }

    private func restBudget(_ s: AppSettings) -> some View {
        let rest = max(0, s.kcalZiel - gegessen)
        let offen = offeneSlots()
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Noch").font(.caption).foregroundStyle(.secondary)
                Text(Format.kcal(rest)).font(.title3.bold())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Slots übrig").font(.caption).foregroundStyle(.secondary)
                Text("\(offen)").font(.title3.bold())
            }
            Spacer()
            Button {
                zustand.tab = .plan
            } label: {
                Label("Plan", systemImage: "arrow.right.circle")
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func logListe() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heute gegessen").font(.headline)
            if heuteLogs.isEmpty {
                Text("Noch nichts eingetragen.").foregroundStyle(.secondary).font(.subheadline)
            } else {
                ForEach(heuteLogs) { log in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(log.foodName.isEmpty ? "Eintrag" : log.foodName)
                            Text(mengeText(log)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Format.kcal(log.kcal)).font(.subheadline.bold())
                        Button(role: .destructive) {
                            context.delete(log); try? context.save()
                        } label: {
                            Image(systemName: "trash").foregroundStyle(Theme.fehler)
                        }
                        .buttonStyle(.borderless)
                    }
                    Divider()
                }
            }
        }
    }

    private func mengeText(_ log: LogEntry) -> String {
        if log.istFestePortion {
            return "\(Format.dezimal(log.portionen, maxNachkomma: 1)) × Portion"
        }
        return "\(Format.gramm(log.netto_g)) netto"
    }

    // MARK: - Aktionen / Berechnungen

    private func wasserHinzufuegen(_ ml: Double) {
        let plan: DayPlan
        if let vorhanden = heuteDayPlans.first {
            plan = vorhanden
        } else {
            let start = Calendar.current.startOfDay(for: Date())
            let neu = DayPlan(datum: start, kcalZiel: settings?.kcalZiel ?? 3000,
                              wasserZiel_ml: settings?.wasserZiel_ml ?? 3000)
            context.insert(neu)
            plan = neu
        }
        plan.wasserGetrunken_ml += ml
        try? context.save()
    }

    private func offeneSlots() -> Int {
        guard let profil = aktivesProfil else { return 0 }
        let jetzt = Uhrzeit.aus(date: Date())
        return profil.slots.filter { $0.uhrzeit >= jetzt && $0.uhrzeit <= profil.cutoff }.count
    }
}
