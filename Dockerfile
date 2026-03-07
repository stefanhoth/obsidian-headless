FROM node:24-slim AS builder

RUN apt-get update && \
    apt-get install -y python3 make g++ && \
    rm -rf /var/lib/apt/lists/*

RUN npm install -g obsidian-headless


FROM node:24-slim

COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=builder /usr/local/bin/ob /usr/local/bin/ob

ENV HOME=/config

# Create a dedicated non-root user and pre-create mount points so
# named volumes are initialized with correct permissions on first run.
RUN groupadd -g 2500 ob && useradd -u 2500 -g ob -s /bin/sh -m ob && \
    mkdir -p /vault /config && chown ob:ob /vault /config

USER ob

WORKDIR /vault

ENTRYPOINT ["ob"]
