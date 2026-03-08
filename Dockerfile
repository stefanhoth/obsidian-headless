FROM node:24-slim AS builder

RUN apt-get update && \
    apt-get install -y python3 make g++ && \
    rm -rf /var/lib/apt/lists/*

RUN npm install -g obsidian-headless


FROM node:24-slim

COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules

# Recreate the symlink that npm would normally create. COPY dereferences
# symlinks, so copying /usr/local/bin/ob directly would break Node.js
# module resolution (modules are resolved relative to the symlink target,
# not the symlink itself).
RUN ln -s /usr/local/lib/node_modules/obsidian-headless/cli.js /usr/local/bin/ob

ENV HOME=/config

# Create a dedicated non-root user and pre-create mount points so
# named volumes are initialized with correct permissions on first run.
RUN groupadd -g 2500 ob && useradd -u 2500 -g ob -s /bin/sh -m ob && \
    mkdir -p /vault /config && chown ob:ob /vault /config

USER ob

WORKDIR /vault

ENTRYPOINT ["ob"]
