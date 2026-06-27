# KalorienPlaner-Sync (selbst-gehosteter Backup-/Sync-Server)

Ein winziger, abhängigkeitsfreier Dienst, der **das Backup-Dokument der App** (das JSON aus
„Datensicherung → Export") authentifiziert und versioniert speichert. Damit:

- überleben deine Daten eine **SideStore-Neuinstallation** (kein manuelles JSON-Hin-und-Her mehr),
- kannst du **mehrere Geräte** abgleichen (Last-Write-Wins auf Dokument-Ebene).

Die iOS-App bleibt **voll offline-fähig** – Sync ist **optional** und wird in der App unter
**Einstellungen → Daten → Cloud-Sync** mit Server-URL + API-Schlüssel aktiviert.

> Wichtig: Dies ist der **Server**. Die iOS-App selbst läuft auf dem iPhone und lässt sich nicht
> in Docker/Linux bauen – nur dieser Begleit-Dienst ist containerisiert.

## Voraussetzungen

- Ein **Linux-VPS** mit **Docker** (+ Docker Compose) oder **Portainer**.
- Eine **Domain** (Subdomain genügt, z. B. `sync.deinedomain.de`), deren **A-Record auf den VPS** zeigt.
  (Nötig für automatisches HTTPS – iOS verlangt eine sichere Verbindung.)
- Offene Ports **80** und **443** am VPS.

## Was läuft hier?

| Dienst | Zweck |
|---|---|
| `sync`  | Der eigentliche Server (Go, statisch, distroless). Lauscht intern auf `:8080`. |
| `caddy` | Reverse-Proxy mit **automatischem HTTPS** (Let's Encrypt) für deine Domain. |

Daten liegen im Docker-Volume `sync-data` (`/data/backup.json` + Meta + Vorgänger-Sicherung).

## Deployment per Docker Compose (SSH)

```bash
git clone <DEIN-REPO-URL>
cd Kcal-Tracker/server
cp .env.example .env
nano .env                 # SYNC_API_KEY und SYNC_DOMAIN setzen
docker compose up -d --build
docker compose logs -f
```

Test:
```bash
curl https://sync.deinedomain.de/health      # -> ok
```

## Deployment per Portainer

1. **Stacks → Add stack.**
2. **Build method: Repository** – Repo-URL eintragen, **Compose path:** `server/docker-compose.yml`.
   (Alternativ „Web editor" und den Inhalt von `docker-compose.yml` einfügen.)
3. Unter **Environment variables** setzen:
   - `SYNC_API_KEY` = langer Zufallswert
   - `SYNC_DOMAIN`  = deine Domain
   - (optional `ACME_EMAIL`, `SYNC_MAX_BODY_BYTES`)
4. **Deploy the stack.** Portainer baut das Image und startet beide Container.
5. Healthcheck wird grün, sobald `sync` antwortet.

## App verbinden

In der App: **Einstellungen → Daten → Cloud-Sync**
- **Server-URL:** `https://sync.deinedomain.de`
- **API-Schlüssel:** derselbe Wert wie `SYNC_API_KEY`
- **„Jetzt hochladen"** sichert den aktuellen Stand, **„Herunterladen"** holt ihn auf ein anderes Gerät.

## API (für Neugierige)

- `GET  /health` → `ok` (ohne Auth, für Healthcheck).
- `GET  /v1/backup` → liefert das gespeicherte JSON (Header `X-Sync-Version`, `X-Sync-Updated-At`). `404`, wenn noch nichts da ist.
- `PUT  /v1/backup` → speichert die JSON-Nutzlast, erhöht die Version. Optional `If-Match: <version>` für optimistische Sperre (`409` bei Konflikt).
- Auth bei `/v1/backup`: Header `Authorization: Bearer <SYNC_API_KEY>`.

## Sicherheit

- **Immer HTTPS** verwenden (Caddy erledigt das). Ohne TLS würden API-Schlüssel und Daten im Klartext übertragen.
- Wähle einen **langen, zufälligen** `SYNC_API_KEY`.
- Der Dienst kennt **keine Accounts**: Wer den Schlüssel hat, hat Zugriff – also geheim halten.
- Sichere zusätzlich das Volume `sync-data` (es enthält deine Daten).

## Ohne eigene Domain (nur lokaler Test)

Für einen schnellen Test im LAN ohne Domain/TLS:
1. In `docker-compose.yml` den `caddy`-Dienst entfernen/auskommentieren und beim `sync`-Dienst die
   `ports: ["8080:8080"]` aktivieren.
2. App-URL: `http://<VPS-IP>:8080`.

> Achtung: Reines HTTP wird von iOS standardmäßig blockiert (App Transport Security) und überträgt
> unverschlüsselt. Nur für lokale Tests – **nicht** fürs offene Internet.
