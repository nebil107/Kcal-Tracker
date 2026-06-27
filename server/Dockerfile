# --- Build-Stufe: statisches Go-Binary (keine externen Abhängigkeiten) ---
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/sync .
RUN mkdir -p /emptydata

# --- Laufzeit: distroless (winzig, keine Shell → minimale Angriffsfläche) ---
FROM gcr.io/distroless/static-debian12
COPY --from=build /out/sync /sync
# Leeres /data ins Image legen, damit ein neues Volume die richtigen Rechte erbt.
COPY --from=build /emptydata /data

ENV SYNC_DATA_DIR=/data \
    SYNC_LISTEN_ADDR=:8080

EXPOSE 8080
VOLUME ["/data"]

# Health-Check ruft das Binary selbst auf (distroless hat keine Shell/curl).
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD ["/sync", "-healthcheck"]

ENTRYPOINT ["/sync"]
