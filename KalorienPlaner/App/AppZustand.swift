import SwiftUI

/// Globaler, beobachtbarer UI-Zustand: aktiver Tab und „Brücke“ von Notification-Aktionen
/// bzw. dem Plan in die Eingabe-Ansicht.
@Observable
final class AppZustand {
    enum Tab: Hashable {
        case heute, plan, lebensmittel, routinen, einstellungen
    }

    var tab: Tab = .heute

    /// Wenn gesetzt, öffnet sich das Eingabe-Formular mit diesem Lebensmittel vorbelegt
    /// (z. B. „Vorschlag eintragen“ aus dem Plan).
    var eingabeVorbelegtFoodID: UUID?

    /// Wird gesetzt, wenn der Nutzer aus einer Notification heraus eine Aktion gewählt hat.
    var letzteNotificationAktion: String?
}
