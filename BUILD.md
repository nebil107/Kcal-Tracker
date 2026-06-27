# BUILD.md – KalorienPlaner ohne Mac bauen (für Windows)

Diese Anleitung führt dich Schritt für Schritt von „nur Windows + iPhone" zu einer fertigen,
installierten App. Du brauchst **keinen Mac** und **kein bezahltes Apple-Entwickler-Konto**.
Der Build läuft kostenlos auf GitHubs macOS-Servern; signiert wird erst auf dem iPhone durch SideStore.

> **Kurzfassung:** GitHub-Repo anlegen → Code hochladen → Actions baut automatisch eine
> unsignierte `KalorienPlaner.ipa` → `.ipa` herunterladen → in SideStore installieren.

---

## Voraussetzungen

- Ein **GitHub-Konto** (kostenlos): <https://github.com/signup>
- **Git für Windows** (zum Hochladen): <https://git-scm.com/download/win>
  *(Alternativ kannst du die Dateien auch direkt im Browser per „Upload files" hochladen – dann ist Git nicht nötig.)*
- Ein iPhone mit **SideStore** bereits eingerichtet (samt deiner Apple-ID).
  Einrichtung von SideStore: <https://sidestore.io>

---

## Schritt 1 – GitHub-Repository anlegen

1. Auf <https://github.com/new> ein neues Repository erstellen.
2. Name z. B. `Kcal-Tracker`.
3. Sichtbarkeit: **Public (öffentlich)** wählen.
   - Grund: Öffentliche Repos haben **unbegrenzte kostenlose** macOS-Build-Minuten.
   - Das Repo enthält **nur Code, keine persönlichen Daten** (deine echten Lebensmittel/Werte
     trägst du erst in der App ein und bleiben nur auf dem iPhone).
4. **Kein** README/`.gitignore`/Lizenz hinzufügen lassen (haben wir schon) → „Create repository".

---

## Schritt 2 – Projekt hochladen (Push)

### Variante A: mit Git (empfohlen)

PowerShell im Projektordner (`...\Desktop\Kcal-Tracker`) öffnen und ausführen
(ersetze `DEIN-NAME` durch deinen GitHub-Benutzernamen):

```powershell
git init
git add .
git commit -m "KalorienPlaner – erste Version"
git branch -M main
git remote add origin https://github.com/DEIN-NAME/Kcal-Tracker.git
git push -u origin main
```

Beim ersten Push fragt Git nach Login – im Browser-Fenster mit GitHub anmelden/bestätigen.

### Variante B: ohne Git (Browser-Upload)

1. Im neuen (leeren) Repo auf **„uploading an existing file"** klicken.
2. **Den gesamten Inhalt** des Ordners `Kcal-Tracker` hineinziehen
   (inklusive der versteckten Ordner `.github` und der Datei `project.yml`).
   - Wichtig: Der Ordner `.github/workflows/build.yml` **muss** mit hochgeladen werden,
     sonst startet kein Build. Falls der Browser versteckte Ordner ausblendet,
     nutze Variante A (Git) – die ist hier zuverlässiger.
3. Unten „Commit changes" klicken.

---

## Schritt 3 – Build starten und beobachten

Der Build startet **automatisch** bei jedem Push. Du kannst ihn auch **manuell** auslösen:

1. Im Repo oben auf den Reiter **„Actions"** gehen.
2. Links den Workflow **„Build KalorienPlaner (unsignierte IPA)"** wählen.
3. Rechts **„Run workflow" → „Run workflow"** klicken (für manuellen Start).
4. Der Lauf besteht aus **zwei unabhängigen Jobs**:
   - **„Unit-Tests (Planungs-Logik)"** – prüft die Engine (Verteilung, Shake, Cutoff, Umverteilung).
   - **„Unsignierte IPA bauen"** – erzeugt das Xcode-Projekt, baut die App **unsigniert** und verpackt
     sie als `KalorienPlaner.ipa`.
   Beide laufen parallel. Der IPA-Job läuft **unabhängig** vom Test-Job – so bekommst du auch dann
   eine `.ipa`, falls mal ein Logik-Test rot ist.

Dauer: typischerweise **5–12 Minuten**. Grüne Haken ✅ = alles ok.
Bei einem roten ✗ den betroffenen Job/Schritt aufklappen – die Fehlermeldung steht dort.
**Wenn nur der Test-Job rot ist, aber der IPA-Job grün:** Die App wurde gebaut, nur ein
Logik-Test schlug fehl – melde mir die Test-Fehlermeldung, dann behebe ich sie.

---

## Schritt 4 – IPA herunterladen

1. Den **erfolgreichen** Workflow-Lauf öffnen.
2. Ganz unten im Abschnitt **„Artifacts"** auf **`KalorienPlaner-unsigned-ipa`** klicken.
3. Es wird eine ZIP-Datei geladen. Diese **entpacken** → darin liegt `KalorienPlaner.ipa`.

---

## Schritt 5 – `.ipa` aufs iPhone und in SideStore installieren

1. `KalorienPlaner.ipa` aufs iPhone bringen, z. B.:
   - per **iCloud Drive** / **Dateien-App**, oder
   - über die SideStore-Funktion zum Laden lokaler `.ipa`-Dateien.
2. In **SideStore** die `.ipa` auswählen und installieren. SideStore **signiert** sie dabei
   automatisch mit deiner Apple-ID – deshalb war im Build **kein** Zertifikat nötig.
3. App-Icon erscheint auf dem Homescreen. Fertig.

> **Hinweis zu kostenlosen Apple-IDs:** Mit einer kostenlosen Apple-ID läuft die Signatur nach
> **7 Tagen** ab; SideStore kann die App im Hintergrund automatisch erneuern (refreshen) – halte
> das in den SideStore-Einstellungen aktiv. Außerdem sind pro Woche nur wenige App-IDs erlaubt.

---

## WICHTIG: Daten sichern vor Neuinstallation

Die App speichert alles **nur lokal auf dem iPhone**. Wenn du die App löschst oder neu
installierst, gehen die Daten verloren. Deshalb:

- In der App unter **Einstellungen → Datensicherung → Exportieren** regelmäßig ein
  **JSON-Backup** erstellen und z. B. in iCloud Drive sichern.
- Nach einer Neuinstallation unter **Einstellungen → Datensicherung → Importieren** wiederherstellen.

---

## Häufige Fragen / Fehlerbehebung

- **„Es startet kein Build."** → Prüfe, ob `.github/workflows/build.yml` im Repo liegt
  (Reiter „Code" → Ordner `.github/workflows`). Fehlt er, nutze Git (Variante A) zum Hochladen.
- **Der Test-Job ist rot.** → Ein Logik-Test ist fehlgeschlagen. Der IPA-Job läuft trotzdem, du
  bekommst also weiterhin eine `.ipa`. Schick mir die Fehlermeldung aus dem Test-Job zum Beheben.
- **„xcodegen: command not found".** → Sollte nicht passieren; der Workflow installiert XcodeGen
  selbst per Homebrew. Tritt es doch auf, war evtl. der Homebrew-Schritt rot – Lauf erneut starten.
- **Kosten?** → Öffentliche Repos: kostenlose macOS-Minuten unbegrenzt. Es entstehen **keine** Kosten.
