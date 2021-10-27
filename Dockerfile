ARG CRYSTAL_VERSION=1.1.1
FROM crystallang/crystal:${CRYSTAL_VERSION}-alpine as build

ARG PLACE_COMMIT="DEV"
ARG PLACE_VERSION="DEV"

WORKDIR /app

# Add trusted CAs for communicating with external services
RUN apk add --update --no-cache \
        bash \
        ca-certificates \
        'libcurl>=7.79.1-r0' \
        libsodium \
        openssh \
        openssl \
    && \
    update-ca-certificates

# Install shards for caching
COPY shard.yml shard.yml
COPY shard.override.yml shard.override.yml
COPY shard.lock shard.lock

# hadolint ignore=DL3003
RUN shards install \
        --production \
        --ignore-crystal-version \
        --skip-postinstall \
        --skip-executables \
    && \
    ( \
        cd lib/sodium \
        && \
        PKG_CONFIG_PATH=$(which pkg-config) \
        bash build/libsodium_install.sh \
    )

# Add src
COPY ./src /app/src

# Build application
ENV UNAME_AT_COMPILE_TIME=true
RUN PLACE_COMMIT=$PLACE_COMMIT \
    PLACE_VERSION=$PLACE_VERSION \
    crystal build --release --debug --error-trace /app/src/app.cr -o triggers

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Extract dependencies
RUN ldd /app/triggers | tr -s '[:blank:]' '\n' | grep '^/' | \
    xargs -I % sh -c 'mkdir -p $(dirname deps%); cp % deps%;'

# Create a non-privileged user, defaults are appuser:10001
ARG IMAGE_UID="10001"
ENV UID=$IMAGE_UID
ENV USER=appuser

# See https://stackoverflow.com/a/55757473/12429735RUN
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    "${USER}"

# Build a minimal docker image
FROM scratch
WORKDIR /
COPY --from=build /app/deps /
COPY --from=build /app/triggers /triggers
COPY --from=build /etc/hosts /etc/hosts

# These provide certificate chain validation where communicating with external services over TLS
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# This is required for Timezone support
COPY --from=build /usr/share/zoneinfo/ /usr/share/zoneinfo/

# Copy the user information over
COPY --from=build /etc/passwd /etc/passwd
COPY --from=build /etc/group /etc/group

# Use an unprivileged user.
USER appuser:appuser

# Run the app binding on port 3000
EXPOSE 3000
HEALTHCHECK CMD ["/triggers", "-c", "http://127.0.0.1:3000/api/triggers/v2/"]
CMD ["/triggers", "-b", "0.0.0.0", "-p", "3000"]
