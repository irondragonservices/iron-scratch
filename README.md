# irondragonservices/iron-scratch

Minimal base image for static binaries — Go, Rust, anything linked with no
libc dependency.

Forked from [ironpeakservices/iron-scratch](https://github.com/ironpeakservices/iron-scratch).

`scratch` on its own gives you nothing, which is the point and also the
problem: no CA certificates, so every outbound TLS connection fails; no
timezone database, so every `LoadLocation` fails; no `/etc/passwd`, so the
container runs as root with no way to say otherwise; and no `/tmp`, so
anything that buffers to disk fails. This adds exactly those four things and
nothing else.

```sh
docker pull ghcr.io/irondragonservices/iron-scratch:3
```

The tag tracks the Alpine release the contents were assembled from.

## Using it

```dockerfile
FROM golang:1.24-alpine AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /app .

FROM ghcr.io/irondragonservices/iron-scratch:3
COPY --from=build /app /app
```

The entrypoint is `/app`, so copying your binary there is all that is needed.
It already runs as uid 1000.

`CGO_ENABLED=0` is not optional — a cgo-linked binary needs a dynamic loader,
and there is not one in here.

## What is in it

| Path | Why |
|---|---|
| `/etc/ssl/certs/ca-certificates.crt` | Outbound TLS fails without it |
| `/usr/share/zoneinfo` | `time.LoadLocation` fails without it |
| `/etc/passwd`, `/etc/group`, `/etc/shadow` | So `USER app` resolves to a real uid |
| `/tmp` | `os.CreateTemp` fails without it |

Verified on every build: a static Go binary in this image reports uid 1000,
creates a temp file, loads a timezone, and completes a TLS handshake.

## Verifying what you pulled

```sh
cosign verify ghcr.io/irondragonservices/iron-scratch:3 \
  --certificate-identity-regexp '^https://github.com/irondragonservices/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Changes from upstream

- **`/tmp` added.** A scratch image has none, and `os.TempDir()` in Go — along
  with most libraries that buffer to disk — assumes one exists.
- **The image label moved to the final stage.** It sat on the builder, where it
  described an image nobody ever pulls, so the published image carried no
  `org.opencontainers.image.source` and GHCR could not link it to a repository.
- Base bumped from `alpine:3.24.0` to `3.24.1` and digest-pinned.
- CI rebuilt as callers into
  [irondragonservices/.github](https://github.com/irondragonservices/.github).
