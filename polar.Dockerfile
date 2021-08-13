# If you change this value, please change it in the following files as well:
# /.travis.yml
# /dev.Dockerfile
# /make/builder.Dockerfile
# /.github/workflows/main.yml
# /.github/workflows/release.yml
FROM golang:1.16.3-alpine as builder

# Force Go to use the cgo based DNS resolver. This is required to ensure DNS
# queries required to connect to linked containers succeed.
ENV GODEBUG netdns=cgo

# Pass a tag, branch or a commit using build-arg.  This allows a docker
# image to be built from a specified Git state.  The default image
# will use the Git tip of master by default.
ARG checkout="master"

# Install dependencies and build the binaries.

RUN apk add --no-cache --update alpine-sdk \
    git \
    make \
    gcc
# Copy in the local repository to build from.
COPY . /go/src/github.com/lightningnetwork/lnd

RUN cd /go/src/github.com/lightningnetwork/lnd \
&&  make release-install

# Start a new, final image.
FROM debian:stable-slim as final

# Add utilities for quality of life and SSL-related reasons. We also require
# curl and gpg for the signature verification script.
RUN apt-get update -y \
  && apt-get install -y curl gosu wait-for-it \
     curl \
     gosu \
     wait-for-it \
     bash \
     jq \
     ca-certificates \
     gnupg \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy the binaries from the builder image.
COPY --from=builder /go/bin/lncli /bin/
COPY --from=builder /go/bin/lnd /bin/
COPY --from=builder /go/src/github.com/lightningnetwork/lnd/scripts/verify-install.sh /

# Store the SHA256 hash of the binaries that were just produced for later
# verification.
RUN sha256sum /bin/lnd /bin/lncli > /shasums.txt \
  && cat /shasums.txt \

VOLUME ["/home/lnd/.lnd"]

# Expose lnd ports (p2p, rpc).
EXPOSE 9735 8080 10009

COPY "docker/lnd/start-polar.sh" /entrypoint.sh
RUN chmod a+x /entrypoint.sh


# Specify the start command and entrypoint as the lnd daemon.
ENTRYPOINT ["/entrypoint.sh"]

CMD ["lnd"]

