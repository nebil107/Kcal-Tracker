import SwiftUI
import SwiftData
import UserNotifications

@main
struct KalorienPlanerApp: App {

    /// Zentraler SwiftData-Container. Lokal gespeichert (kein iCloud-Sync erzwungen).
    let container: ModelContainer

    @State private var zustand = AppZustand()

    init() {
        do {
            // Alle persistierten Modelle. (CloudKit-kompatibel aufgebaut, Sync aber deaktiviert.)
            container = try ModelContainer(
                for: Food.self, Behaelter.self, MealSlot.self, DayPlan.self,
                     LogEntry.self, RoutineProfil.self, AppSettings.self)
        } catch {
            fatalError("ModelContainer konnte nicht erstellt werden: \(error)")
        }

        // Erste Einrichtung: Einstellungen anlegen + seed.json importieren (nur beim 1. Start).
        SeedImporter.ersteEinrichtung(context: container.mainContext)

        // Lokale Notifications vorbereiten (Kategorien + Aktions-Buttons).
        NotificationManager.shared.kategorienRegistrieren()
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(zustand)
                .onAppear {
                    // Notification-Aktionen in den UI-Zustand spiegeln (öffnet u. a. den Plan-Tab).
                    NotificationManager.shared.aktionHandler = { aktion in
                        zustand.letzteNotificationAktion = aktion
                        zustand.tab = .plan
                    }
                }
        }
        .modelContainer(container)
    }
}
