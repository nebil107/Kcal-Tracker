import SwiftUI
import SwiftData

/// Liste der Routine-Profile mit Aktivierung, Bearbeiten und Löschen.
struct RoutineProfilListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RoutineProfil.name) private var profile: [RoutineProfil]
    @Query private var settingsListe: [AppSettings]

    @State private var zeigeNeu = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(profile) { profil in
                    NavigationLink {
                        RoutineProfilEditView(profil: profil)
                    } label: {
                        zeile(profil)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            context.delete(profil); try? context.save()
                        } label: { Label("Löschen", systemImage: "trash") }
                    }
                }
            }
            .navigationTitle("Routinen")
            .overlay {
                if profile.isEmpty {
                    ContentUnavailableView("Keine Profile", systemImage: "clock",
                        description: Text("Lege ein Profil mit deinen Essenszeiten an."))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { zeigeNeu = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $zeigeNeu) { RoutineProfilEditView(profil: nil) }
        }
    }

    private func zeile(_ profil: RoutineProfil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(profil.name.isEmpty ? "Profil" : profil.name).font(.headline)
                    if profil.aktiv {
                        Text("aktiv").font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.akzent).foregroundStyle(.white).clipShape(Capsule())
                    }
                }
                Text("\(profil.slots.count) Slots · Cutoff \(profil.cutoff.anzeige)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !profil.aktiv {
                Button("Aktivieren") { aktivieren(profil) }
                    .buttonStyle(.bordered).font(.caption)
            }
        }
    }

    private func aktivieren(_ profil: RoutineProfil) {
        for p in profile { p.aktiv = (p.id == profil.id) }
        try? context.save()
        if settingsListe.first?.benachrichtigungenAktiv == true {
            NotificationManager.shared.slotErinnerungenPlanen(profil: profil)
        }
    }
}
