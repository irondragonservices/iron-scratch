FROM alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS builder

# add ca certificates and timezone data files
# hadolint ignore=DL3018
RUN apk add -U --no-cache ca-certificates tzdata

# add unprivileged user
RUN adduser -s /bin/true -u 1000 -D -h /app app \
  && sed -i -r "/^(app|root)/!d" /etc/group /etc/passwd \
  && sed -i -r 's#^(.*):[^:]*$#\1:/sbin/nologin#' /etc/passwd

# A scratch image has no /tmp, and os.TempDir() in Go — along with most
# libraries that buffer to disk — assumes one exists. Built here so it arrives
# with the right ownership and mode rather than as a root-owned 0755 directory.
RUN mkdir -m 1777 /emptytmp

# start with empty image
FROM scratch

# The label belongs on the final stage. On the builder it describes an image
# nobody ever pulls.
LABEL org.opencontainers.image.source="https://github.com/irondragonservices/iron-scratch"

# add-in our timezone data file
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# add-in our unprivileged user
COPY --from=builder /etc/passwd /etc/group /etc/shadow /etc/

# add-in our ca certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# add-in a writable temp directory
COPY --from=builder --chown=1000:1000 /emptytmp /tmp

# from now on, run as the unprivileged user
USER app

# entrypoint
ENTRYPOINT ["/app"]
