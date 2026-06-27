// KalorienPlaner-Sync: ein minimaler, selbst-gehosteter Backup-/Sync-Server.
//
// Aufgabe: speichert genau EIN Backup-Dokument (das JSON, das die iOS-App per
// "Datensicherung → Export" erzeugt) authentifiziert und versioniert ab.
// Damit überleben die Daten eine SideStore-Neuinstallation und lassen sich
// zwischen mehreren Geräten abgleichen (Last-Write-Wins auf Dokument-Ebene).
//
// Der Server ist absichtlich „dumm": er kennt das interne Format nicht, sondern
// behandelt die Nutzlast als opake JSON-Bytes. Keine externen Abhängigkeiten.
//
// Konfiguration ausschließlich über Umgebungsvariablen:
//   SYNC_API_KEY         (Pflicht) geheimer Schlüssel; identisch in der App eintragen
//   SYNC_DATA_DIR        Datenverzeichnis (Default /data, als Volume gemountet)
//   SYNC_LISTEN_ADDR     Listen-Adresse (Default :8080)
//   SYNC_MAX_BODY_BYTES  max. Upload-Größe (Default 52428800 = 50 MB)
package main

import (
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

func main() {
	healthcheck := flag.Bool("healthcheck", false, "interner Health-Check (für Docker HEALTHCHECK), beendet sich danach")
	flag.Parse()

	addr := getenv("SYNC_LISTEN_ADDR", ":8080")

	// Wird vom Docker-HEALTHCHECK aufgerufen (distroless hat keine Shell/curl).
	if *healthcheck {
		os.Exit(runHealthcheck(addr))
	}

	apiKey := strings.TrimSpace(os.Getenv("SYNC_API_KEY"))
	if apiKey == "" {
		log.Fatal("SYNC_API_KEY ist nicht gesetzt – der Server startet aus Sicherheitsgründen nicht.")
	}
	dataDir := getenv("SYNC_DATA_DIR", "/data")
	maxBody := int64(getenvInt("SYNC_MAX_BODY_BYTES", 52*1024*1024))

	st, err := newStore(dataDir)
	if err != nil {
		log.Fatalf("Datenverzeichnis %q konnte nicht initialisiert werden: %v", dataDir, err)
	}

	mux := http.NewServeMux()

	// Ohne Auth – nur für Docker/Portainer-Healthcheck.
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = io.WriteString(w, "ok")
	})

	mux.HandleFunc("/v1/backup", func(w http.ResponseWriter, r *http.Request) {
		if !authOK(r, apiKey) {
			writeErr(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		switch r.Method {
		case http.MethodGet:
			handleGet(w, st)
		case http.MethodPut:
			handlePut(w, r, st, maxBody)
		default:
			writeErr(w, http.StatusMethodNotAllowed, "method not allowed")
		}
	})

	srv := &http.Server{
		Addr:              addr,
		Handler:           logging(mux),
		ReadHeaderTimeout: 10 * time.Second,
	}
	log.Printf("KalorienPlaner-Sync lauscht auf %s (Daten: %s, max. Upload: %d Bytes)", addr, dataDir, maxBody)
	log.Fatal(srv.ListenAndServe())
}

// MARK: - HTTP-Handler

func handleGet(w http.ResponseWriter, st *store) {
	data, m, ok, err := st.get()
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "read failed")
		return
	}
	if !ok {
		writeErr(w, http.StatusNotFound, "no backup yet")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-Sync-Version", strconv.Itoa(m.Version))
	w.Header().Set("X-Sync-Updated-At", m.UpdatedAt.Format(time.RFC3339))
	w.Header().Set("X-Sync-SHA256", m.SHA256)
	_, _ = w.Write(data)
}

func handlePut(w http.ResponseWriter, r *http.Request, st *store, maxBody int64) {
	r.Body = http.MaxBytesReader(w, r.Body, maxBody)
	payload, err := io.ReadAll(r.Body)
	if err != nil {
		writeErr(w, http.StatusRequestEntityTooLarge, "body too large or unreadable")
		return
	}
	if len(payload) == 0 {
		writeErr(w, http.StatusBadRequest, "empty body")
		return
	}
	if !json.Valid(payload) {
		writeErr(w, http.StatusBadRequest, "payload is not valid JSON")
		return
	}

	// Optionale optimistische Sperre: If-Match: <version>
	expected, hasExpected := 0, false
	if im := strings.Trim(r.Header.Get("If-Match"), `"`); im != "" {
		if v, e := strconv.Atoi(im); e == nil {
			expected, hasExpected = v, true
		}
	}

	m, err := st.put(payload, expected, hasExpected)
	if err != nil {
		var c errConflict
		if errors.As(err, &c) {
			w.Header().Set("X-Sync-Version", strconv.Itoa(c.current))
			writeErr(w, http.StatusConflict, fmt.Sprintf("version conflict, current=%d", c.current))
			return
		}
		writeErr(w, http.StatusInternalServerError, "write failed")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"version":   m.Version,
		"updatedAt": m.UpdatedAt.Format(time.RFC3339),
		"size":      m.Size,
	})
}

// MARK: - Auth & Helfer

func authOK(r *http.Request, key string) bool {
	const prefix = "Bearer "
	h := r.Header.Get("Authorization")
	if !strings.HasPrefix(h, prefix) {
		return false
	}
	got := strings.TrimSpace(h[len(prefix):])
	return subtle.ConstantTimeCompare([]byte(got), []byte(key)) == 1
}

func writeErr(w http.ResponseWriter, code int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func getenvInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

func runHealthcheck(addr string) int {
	host := addr
	if strings.HasPrefix(host, ":") {
		host = "127.0.0.1" + host
	}
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get("http://" + host + "/health")
	if err != nil {
		return 1
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusOK {
		return 0
	}
	return 1
}

// MARK: - Logging-Middleware

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

func logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		start := time.Now()
		next.ServeHTTP(rec, r)
		log.Printf("%s %s -> %d (%s)", r.Method, r.URL.Path, rec.status, time.Since(start))
	})
}

// MARK: - Speicher (dateibasiert, atomar, mit Vorgänger-Sicherung)

type fileMeta struct {
	Version   int       `json:"version"`
	UpdatedAt time.Time `json:"updatedAt"`
	Size      int       `json:"size"`
	SHA256    string    `json:"sha256"`
}

type store struct {
	mu       sync.Mutex
	dataPath string
	prevPath string
	metaPath string
}

type errConflict struct{ current int }

func (e errConflict) Error() string { return fmt.Sprintf("version conflict, current=%d", e.current) }

func newStore(dir string) (*store, error) {
	if err := os.MkdirAll(dir, 0o750); err != nil {
		return nil, err
	}
	return &store{
		dataPath: filepath.Join(dir, "backup.json"),
		prevPath: filepath.Join(dir, "backup.prev.json"),
		metaPath: filepath.Join(dir, "backup.meta.json"),
	}, nil
}

func (s *store) readMeta() (fileMeta, bool, error) {
	b, err := os.ReadFile(s.metaPath)
	if errors.Is(err, os.ErrNotExist) {
		return fileMeta{}, false, nil
	}
	if err != nil {
		return fileMeta{}, false, err
	}
	var m fileMeta
	if err := json.Unmarshal(b, &m); err != nil {
		return fileMeta{}, false, err
	}
	return m, true, nil
}

func (s *store) get() ([]byte, fileMeta, bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	m, ok, err := s.readMeta()
	if err != nil || !ok {
		return nil, fileMeta{}, ok, err
	}
	data, err := os.ReadFile(s.dataPath)
	if err != nil {
		return nil, fileMeta{}, false, err
	}
	return data, m, true, nil
}

func (s *store) put(payload []byte, expected int, hasExpected bool) (fileMeta, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	cur, ok, err := s.readMeta()
	if err != nil {
		return fileMeta{}, err
	}
	curVer := 0
	if ok {
		curVer = cur.Version
	}
	if hasExpected && expected != curVer {
		return fileMeta{}, errConflict{current: curVer}
	}

	// Vorherige Version sichern (einfacher Schutz vor versehentlichem Überschreiben).
	if ok {
		_ = copyFile(s.dataPath, s.prevPath)
	}
	if err := atomicWrite(s.dataPath, payload); err != nil {
		return fileMeta{}, err
	}
	sum := sha256.Sum256(payload)
	m := fileMeta{
		Version:   curVer + 1,
		UpdatedAt: time.Now().UTC(),
		Size:      len(payload),
		SHA256:    hex.EncodeToString(sum[:]),
	}
	mb, _ := json.MarshalIndent(m, "", "  ")
	if err := atomicWrite(s.metaPath, mb); err != nil {
		return fileMeta{}, err
	}
	return m, nil
}

func atomicWrite(path string, data []byte) error {
	tmp := path + ".tmp"
	f, err := os.OpenFile(tmp, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o640)
	if err != nil {
		return err
	}
	if _, err := f.Write(data); err != nil {
		f.Close()
		return err
	}
	if err := f.Sync(); err != nil {
		f.Close()
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func copyFile(src, dst string) error {
	b, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return atomicWrite(dst, b)
}
