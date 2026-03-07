FROM node:24-slim AS builder

RUN apt-get update && \
    apt-get install -y python3 make g++ && \
    rm -rf /var/lib/apt/lists/*

RUN npm install -g obsidian-headless


FROM node:24-slim

COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=builder /usr/local/bin/ob /usr/local/bin/ob

ENV HOME=/config

# Pre-create mount points owned by the node user so named volumes
# are initialized with correct permissions on first run.
RUN mkdir -p /vault /config && chown node:node /vault /config

USER node

WORKDIR /vault

ENTRYPOINT ["ob"]
