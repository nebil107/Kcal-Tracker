import SwiftUI

/// Haupt-Navigation: Heute · Plan · Lebensmittel · Routinen · Einstellungen.
struct RootTabView: View {
    @Environment(AppZustand.self) private var zustand

    var body: some View {
        @Bindable var zustand = zustand
        TabView(selection: $zustand.tab) {
            DashboardView()
                .tabItem { Label("Heute", systemImage: "flame.fill") }
                .tag(AppZustand.Tab.heute)

            PlanView()
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(AppZustand.Tab.plan)

            FoodListView()
                .tabItem { Label("Lebensmittel", systemImage: "fork.knife") }
                .tag(AppZustand.Tab.lebensmittel)

            RoutineProfilListView()
                .tabItem { Label("Routinen", systemImage: "clock.arrow.circlepath") }
                .tag(AppZustand.Tab.routinen)

            SettingsView()
                .tabItem { Label("Mehr", systemImage: "gearshape.fill") }
                .tag(AppZustand.Tab.einstellungen)
        }
    }
}
