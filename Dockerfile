# Bitly PWA — Dockerfile multi-stage
# Build: docker build -t bitly-pwa .
# Run:   docker run -p 8080:8080 -v bitly-data:/data bitly-pwa

# ── Stage 1: Build Go backend ──────────────────────────────────────
FROM golang:1.23-alpine AS go-builder
WORKDIR /src
COPY go_backend/ ./go_backend/
RUN cd go_backend && go build -ldflags="-s -w" -o /bitly-backend ./cmd/server

# ── Stage 2: Build Flutter web ─────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:3.41.6 AS flutter-builder
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY lib/ ./lib/
COPY web/ ./web/
COPY assets/ ./assets/
COPY lib/config/secretos.example.dart lib/config/secretos.dart
RUN flutter build web --release --base-href /

# ── Stage 3: Runtime ──────────────────────────────────────────────
FROM alpine:3.19
RUN apk add --no-cache ca-certificates tzdata
RUN adduser -D -u 1000 bitly
WORKDIR /app

# Copiar backend Go compilado
COPY --from=go-builder /bitly-backend /app/bitly-backend

# Copiar Flutter web compilado
COPY --from=flutter-builder /src/build/web/ /app/web/

# Datos persistentes (descargas, cache, sesiones)
RUN mkdir -p /data && chown bitly:bitly /data
VOLUME /data

USER bitly
ENV WEB_MODE=1
ENV PORT=8080
ENV WEB_DIR=/app/web

EXPOSE 8080

# El backend escucha en 0.0.0.0:8080 y sirve:
# - Archivos estáticos de Flutter web (/, /index.html, etc.)
# - API de música (/api/*, /search, /stream, /cover, /download, /feed)
CMD ["/app/bitly-backend"]
