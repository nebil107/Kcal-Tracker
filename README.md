# KalorienPlaner

Eine native iOS-App (SwiftUI + SwiftData, iOS 17), die deinen Tagesablauf rund ums Essen
**plant** statt nur zu protokollieren. Komplett **offline**, **kein Login**, **kein Server**,
**kein Tracking**, **0 € laufende Kosten**. Oberfläche durchgehend auf **Deutsch**.

Installation per **SideStore** – der Build erzeugt eine **unsignierte `.ipa`**, die SideStore
direkt auf dem iPhone signiert. Es wird **kein Mac und kein Apple-Entwickler-Konto** benötigt.

## Kernidee

- **Planungs-Engine (Herzstück):** verteilt dein Kalorienziel auf deine Essensfenster, respektiert
  Aufwachzeit & Cutoff, entscheidet Kochen vs. No-Cook, plant **immer mindestens einen Shake** ein
  und verteilt bei Ablehnung flexibel um. Reine, lokale Logik – kein KI-Dienst, keine Cloud.
- **Alles editierbar:** Lebensmittel, Nährwerte, Kalorien-/Makro-/Wasserziel, Behälter-Gewichte,
  Essenszeiten und Slot-Gewichtung. Nichts ist fest verdrahtet (Standard-Kalorienziel = 3000).
- **Tara-Berechnung beim Eintragen:** Behälter wählen → Tara wird abgezogen → kcal & Makros live.
- **Datensicherung:** kompletter JSON-Export/Import (wichtig vor SideStore-Neuinstallation).

## Bauen ohne Mac

Siehe **[BUILD.md](BUILD.md)** – Schritt-für-Schritt-Anleitung für Windows: GitHub-Repo anlegen,
Projekt pushen, GitHub-Actions-Build starten, `.ipa` herunterladen und in SideStore installieren.

## Projektstruktur (Kurzüberblick)

```
project.yml              XcodeGen-Spezifikation (CI erzeugt daraus die .xcodeproj)
.github/workflows/       GitHub-Actions-Build (Tests + unsignierte IPA)
KalorienPlaner/
  App/                   Einstieg, ModelContainer, Seed beim ersten Start
  Models/                SwiftData-Modelle (alles editierbar)
  Engine/                reine Planungs-Logik (ohne UI/SwiftData) + Tests-Basis
  Services/              Nährwert-Rechner, lokale Notifications
  Persistence/           Seed-Import, JSON-Backup/Restore
  Views/                 Oberfläche (Dashboard, Plan, Eintragen, Verwaltung)
  Resources/             seed.json, Assets
KalorienPlanerTests/     Unit-Tests der Engine
```

## Deine Lebensmittel hinzufügen

Drei Wege (von „am einfachsten" bis „beim ersten Start"):

1. **CSV-Import (empfohlen für eine ganze Liste):** Öffne `lebensmittel-vorlage.csv` in Excel /
   Google Sheets, fülle Zeilen aus, speichere als CSV. In der App: Tab **Lebensmittel → „+" →
   „Aus CSV importieren"** → Datei wählen. Jederzeit wiederholbar; gleicher Name = Eintrag wird
   aktualisiert (nicht doppelt).
   - Spalten: `name; kategorie; kcal; protein; fett; kohlenhydrate; feste_portion; portionsname;
     standardportion_g; shake; kochaufwand; tageszeiten; tags`
   - Nur `name` ist Pflicht; fehlende Spalten/leere Zellen bleiben unverändert.
   - Werte je **100 g** – außer bei `feste_portion = ja`, dann **pro Portion**.
   - `;` oder `,` als Trennzeichen und Komma/Punkt als Dezimal werden beide erkannt.
2. **Einzeln in der App:** Tab **Lebensmittel → „+" → „Neues Lebensmittel"**.
3. **`seed.json`:** nur beim allerersten Start importiert – gut, um die App schon vorbefüllt
   auszuliefern (`KalorienPlaner/Resources/seed.json`).

## Optionaler Cloud-Sync (selbst gehostet)

Standardmäßig läuft alles offline (Backups via JSON-Export). **Optional** gibt es einen winzigen,
selbst-gehosteten Sync-Server (`server/`), den du per Docker/Portainer auf einem Linux-VPS betreibst –
damit syncen deine Daten geräteübergreifend und überleben eine SideStore-Neuinstallation. Aktivierung
in der App unter **Einstellungen → Daten → Cloud-Sync**. Einrichtung: siehe **[server/README.md](server/README.md)**.

> Hinweis: Nur dieser Begleit-Server ist containerisiert. Die iOS-App selbst lässt sich nicht in
> Docker/Linux bauen (dafür der macOS-GitHub-Actions-Build, siehe BUILD.md).

## Status / bewusste Nicht-Ziele

Barcode-Scanner und Foto-Erkennung sind aktuell **nicht** enthalten (die Datenstruktur ist aber
offen dafür). Apple-iCloud-Sync ist bewusst deaktiviert (bräuchte ein kostenpflichtiges Apple-Konto) –
stattdessen JSON-Export bzw. der optionale selbst-gehostete Sync oben.
