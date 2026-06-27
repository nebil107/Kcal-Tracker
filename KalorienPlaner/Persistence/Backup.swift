import Foundation
import SwiftData

/// Export/Import der kompletten Datenbank als JSON.
/// Wichtig vor einer SideStore-Neuinstallation, da sonst alle lokalen Daten verloren gehen.
enum Backup {

    enum BackupFehler: LocalizedError {
        case ungueltigeDatei
        var errorDescription: String? {
            switch self {
            case .ungueltigeDatei: return "Die Datei konnte nicht als gültiges Backup gelesen werden."
            }
        }
    }

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Export

    static func exportieren(context: ModelContext) throws -> Data {
        var datei = BackupDatei()
        if let s = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first {
            datei.settings = SettingsDTO(s)
        }
        datei.foods = ((try? context.fetch(FetchDescriptor<Food>())) ?? []).map(FoodDTO.init)
        datei.behaelter = ((try? context.fetch(FetchDescriptor<Behaelter>())) ?? []).map(BehaelterDTO.init)
        datei.profile = ((try? context.fetch(FetchDescriptor<RoutineProfil>())) ?? []).map(ProfilDTO.init)
        datei.logs = ((try? context.fetch(FetchDescriptor<LogEntry>())) ?? []).map(LogDTO.init)
        datei.dayPlans = ((try? context.fetch(FetchDescriptor<DayPlan>())) ?? []).map(DayPlanDTO.init)
        return try encoder().encode(datei)
    }

    /// Schreibt das Backup in eine temporäre Datei und gibt deren URL zurück (zum Teilen).
    static func exportDatei(context: ModelContext) throws -> URL {
        let data = try exportieren(context: context)
        let name = "KalorienPlaner-Backup-\(dateiDatum()).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func dateiDatum() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f.string(from: Date())
    }

    // MARK: - Import (Wiederherstellung)

    /// Ersetzt den kompletten Datenbestand durch das Backup.
    static func importieren(data: Data, context: ModelContext) throws {
        let datei: BackupDatei
        do {
            datei = try decoder().decode(BackupDatei.self, from: data)
        } catch {
            throw BackupFehler.ungueltigeDatei
        }

        loescheAlles(context: context)

        // Foods & Behälter zuerst (für die Verknüpfung der Logs nötig).
        var foodMap: [UUID: Food] = [:]
        for dto in datei.foods {
            let f = dto.alsFood(); context.insert(f); foodMap[f.id] = f
        }
        var behaelterMap: [UUID: Behaelter] = [:]
        for dto in datei.behaelter {
            let b = dto.alsBehaelter(); context.insert(b); behaelterMap[b.id] = b
        }
        for dto in datei.profile { context.insert(dto.alsProfil()) }
        for dto in datei.logs {
            let l = dto.alsLog()
            if let fid = dto.foodId { l.food = foodMap[fid] }
            if let bid = dto.behaelterId { l.behaelter = behaelterMap[bid] }
            context.insert(l)
        }
        for dto in datei.dayPlans { context.insert(dto.alsDayPlan()) }

        // Einstellungen: bestehende Instanz wiederverwenden (es bleibt genau eine).
        let settings = SeedImporter.ersteEinrichtung(context: context)
        if let s = datei.settings { s.anwenden(auf: settings) }
        settings.seedImportiert = true // nach Restore keinen erneuten Seed-Import auslösen

        try context.save()
    }

    private static func loescheAlles(context: ModelContext) {
        func loesche<T: PersistentModel>(_ type: T.Type) {
            for objekt in (try? context.fetch(FetchDescriptor<T>())) ?? [] {
                context.delete(objekt)
            }
        }
        loesche(LogEntry.self)
        loesche(MealSlot.self)
        loesche(DayPlan.self)
        loesche(RoutineProfil.self)
        loesche(Behaelter.self)
        loesche(Food.self)
        loesche(AppSettings.self)
    }
}
