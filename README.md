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
  --certificate-identity-regexp '^https://github\.com/irondragonservices/\.github/\.github/workflows/image-(release|refresh)\.yml@refs/heads/main$' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-github-workflow-repository irondragonservices/iron-scratch
```

Be precise about the identity. The signature is produced by the shared
reusable workflow in
[irondragonservices/.github](https://github.com/irondragonservices/.github),
not by a workflow in this repository, so the certificate names *that* path.
A looser pattern such as `^https://github.com/irondragonservices/` would
accept a signature from any workflow in any repository in the organisation,
which is a much weaker claim than it looks. The
`--certificate-github-workflow-repository` flag is what ties the signature back
to this repository.

Both `image-release` and `image-refresh` sign: the nightly rebuild republishes
when the package set has actually changed, and it signs what it pushes.

## Changes from upstream

- **The base packages are now upgraded, not just added to.** The step commented
  *update base system* only installed `ca-certificates`, so the image shipped
  whatever the base image tag happened to contain. Distributions patch a
  package well before they rebuild and republish the base image, so a digest
  pin — which is what Renovate maintains — pins the *unpatched* set until
  upstream gets round to a rebuild. `alpine:3.24.1` was carrying openssl
  3.5.7-r0 with a fixed HIGH against it and 3.5.8-r0 already in the repository.
  This is also what makes the nightly cache-free rebuild worth running: without
  it, that job rebuilt the same packages every night and picked up nothing.
- **`/tmp` added.** A scratch image has none, and `os.TempDir()` in Go — along
  with most libraries that buffer to disk — assumes one exists.
- **The image label moved to the final stage.** It sat on the builder, where it
  described an image nobody ever pulls, so the published image carried no
  `org.opencontainers.image.source` and GHCR could not link it to a repository.
- Base bumped from `alpine:3.24.0` to `3.24.1` and digest-pinned.
- CI rebuilt as callers into
  [irondragonservices/.github](https://github.com/irondragonservices/.github).
