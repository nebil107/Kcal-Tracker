import Foundation
import SwiftData

/// Lese-/Hilfsfunktionen rund um den heutigen Tag (Logs, Wasser, aktives Profil).
enum Tagesdaten {

    /// Alle LogEntries eines Tages (Standard: heute), zeitlich sortiert.
    static func logs(context: ModelContext, datum: Date = Date()) -> [LogEntry] {
        let start = Calendar.current.startOfDay(for: datum)
        guard let ende = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return [] }
        let pred = #Predicate<LogEntry> { $0.zeitstempel >= start && $0.zeitstempel < ende }
        let desc = FetchDescriptor<LogEntry>(predicate: pred, sortBy: [SortDescriptor(\.zeitstempel)])
        return (try? context.fetch(desc)) ?? []
    }

    /// LogEntries der letzten `tage` Tage (für die VarietyPenalty der Engine).
    static func letzteLogs(context: ModelContext, tage: Int = 7, jetzt: Date = Date()) -> [LogEntry] {
        guard let grenze = Calendar.current.date(byAdding: .day, value: -tage, to: jetzt) else { return [] }
        let pred = #Predicate<LogEntry> { $0.zeitstempel >= grenze }
        let desc = FetchDescriptor<LogEntry>(predicate: pred, sortBy: [SortDescriptor(\.zeitstempel, order: .reverse)])
        return (try? context.fetch(desc)) ?? []
    }

    static func gegessenKcal(_ logs: [LogEntry]) -> Double { logs.reduce(0) { $0 + $1.kcal } }
    static func gegessenMakros(_ logs: [LogEntry]) -> Makros { logs.reduce(Makros.null) { $0 + $1.makros } }

    /// Holt den heutigen DayPlan oder legt ihn an (für Wasser-Stand & Tagesziele).
    static func heutigerDayPlan(context: ModelContext, settings: AppSettings) -> DayPlan {
        let start = Calendar.current.startOfDay(for: Date())
        let pred = #Predicate<DayPlan> { $0.datum == start }
        if let vorhanden = (try? context.fetch(FetchDescriptor<DayPlan>(predicate: pred)))?.first {
            return vorhanden
        }
        let neu = DayPlan(datum: start, kcalZiel: settings.kcalZiel, wasserZiel_ml: settings.wasserZiel_ml)
        context.insert(neu)
        return neu
    }

    /// Aktives Routine-Profil (oder das erste vorhandene als Fallback).
    static func aktivesProfil(context: ModelContext) -> RoutineProfil? {
        let pred = #Predicate<RoutineProfil> { $0.aktiv }
        if let aktiv = (try? context.fetch(FetchDescriptor<RoutineProfil>(predicate: pred)))?.first {
            return aktiv
        }
        return (try? context.fetch(FetchDescriptor<RoutineProfil>()))?.first
    }

    static func alleEinstellungen(context: ModelContext) -> AppSettings {
        SeedImporter.ersteEinrichtung(context: context)
    }
}
