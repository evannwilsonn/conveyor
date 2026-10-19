# MagicStream's Go API. Build context: ./src (see fetch.sh).
#   dev   `go run` with the source mounted by compose watch
#   build compiles a static binary
#   run   the binary alone on Alpine, as a non-root user (about 25 MB)
FROM golang:1.24-alpine AS base
WORKDIR /src
COPY Server/MagicStreamServer/go.mod Server/MagicStreamServer/go.sum ./
RUN go mod download

FROM base AS dev
COPY Server/MagicStreamServer/ ./
EXPOSE 8080
CMD ["go", "run", "."]

FROM base AS build
COPY Server/MagicStreamServer/ ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /magicstream-api .

FROM alpine:3.20 AS run
RUN adduser -D -u 10001 api && apk add --no-cache ca-certificates
COPY --from=build /magicstream-api /usr/local/bin/magicstream-api
USER api
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s CMD wget -qO- http://127.0.0.1:8080/hello >/dev/null || exit 1
ENTRYPOINT ["magicstream-api"]
