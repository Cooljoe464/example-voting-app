FROM node:18.20.8-bookworm-slim@sha256:f9ab18e354e6855ae56ef2b290dd225c1e51a564f87584b9bd21dd651838830e

# add curl for healthcheck
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl tini && \
    rm -rf /var/lib/apt/lists/*

# Create an unprivileged user to run the application
RUN groupadd --gid 10001 app && \
    useradd --uid 10001 --gid app --create-home --shell /usr/sbin/nologin app

WORKDIR /usr/local/app

# have nodemon available for local dev use (file watching)
RUN npm install -g nodemon@3.1.14

COPY package*.json ./

RUN npm ci && \
 npm cache clean --force && \
 mv /usr/local/app/node_modules /node_modules

COPY --chown=app:app . .

ENV PORT=8080
EXPOSE 8080

# Run as an unprivileged user
USER app

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "server.js"]
