import Foundation
import UserNotifications

/// Verwaltet lokale Erinnerungen (Slot-Zeiten + optional Wasser). Rein lokal – keine
/// kostenpflichtigen Entitlements. Bietet Aktions-Buttons [Annehmen]/[Ablehnen].
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()
    private override init() { super.init() }

    static let kategorieSlot = "SLOT_VORSCHLAG"
    static let aktionAnnehmen = "AKTION_ANNEHMEN"
    static let aktionAblehnen = "AKTION_ABLEHNEN"

    private static let slotPrefix = "slot-"
    private static let wasserPrefix = "wasser-"

    /// Wird aufgerufen, wenn der Nutzer eine Notification-Aktion auswählt (Action-Identifier).
    var aktionHandler: ((String) -> Void)?

    // MARK: - Setup

    func kategorienRegistrieren() {
        let annehmen = UNNotificationAction(identifier: Self.aktionAnnehmen, title: "Annehmen", options: [.foreground])
        let ablehnen = UNNotificationAction(identifier: Self.aktionAblehnen, title: "Ablehnen", options: [.foreground])
        let kategorie = UNNotificationCategory(
            identifier: Self.kategorieSlot,
            actions: [annehmen, ablehnen],
            intentIdentifiers: [],
            options: [])
        UNUserNotificationCenter.current().setNotificationCategories([kategorie])
    }

    /// Fragt die Berechtigung an. Gibt zurück, ob erlaubt wurde.
    @discardableResult
    func berechtigungAnfragen() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // MARK: - Planung

    /// Plant tägliche Slot-Erinnerungen anhand der Slot-Zeiten des aktiven Profils.
    func slotErinnerungenPlanen(profil: RoutineProfil) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { anfragen in
            let alteIds = anfragen.map(\.identifier).filter { $0.hasPrefix(Self.slotPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: alteIds)

            for slot in profil.slots {
                let content = UNMutableNotificationContent()
                content.title = "Zeit für \(slot.tageszeit.anzeige)"
                content.body = "Tippe für deinen Vorschlag – Annehmen oder Ablehnen."
                content.categoryIdentifier = Self.kategorieSlot
                content.sound = .default

                var dc = DateComponents()
                dc.hour = slot.stunde
                dc.minute = slot.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)

                let req = UNNotificationRequest(
                    identifier: "\(Self.slotPrefix)\(slot.id.uuidString)",
                    content: content, trigger: trigger)
                center.add(req)
            }
        }
    }

    /// Optionale Wasser-Erinnerungen in einem Stundenraster.
    func wasserErinnerungenPlanen(vonStunde: Int = 9, bisStunde: Int = 21, intervallStunden: Int = 2) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { anfragen in
            let alteIds = anfragen.map(\.identifier).filter { $0.hasPrefix(Self.wasserPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: alteIds)

            guard intervallStunden > 0 else { return }
            var stunde = vonStunde
            while stunde <= bisStunde {
                let content = UNMutableNotificationContent()
                content.title = "Trinken nicht vergessen"
                content.body = "Zeit für ein Glas Wasser."
                content.sound = .default
                var dc = DateComponents(); dc.hour = stunde; dc.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                center.add(UNNotificationRequest(identifier: "\(Self.wasserPrefix)\(stunde)",
                                                 content: content, trigger: trigger))
                stunde += intervallStunden
            }
        }
    }

    func slotErinnerungenEntfernen() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { anfragen in
            let ids = anfragen.map(\.identifier).filter { $0.hasPrefix(Self.slotPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func wasserErinnerungenEntfernen() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { anfragen in
            let ids = anfragen.map(\.identifier).filter { $0.hasPrefix(Self.wasserPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func alleEntfernen() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Notifications auch im Vordergrund anzeigen.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Reaktion auf Annehmen/Ablehnen (öffnet die App; die eigentliche Umverteilung geschieht im Plan).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let aktion = response.actionIdentifier
        await MainActor.run { aktionHandler?(aktion) }
    }
}
