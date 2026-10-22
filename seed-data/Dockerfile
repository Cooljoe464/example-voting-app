FROM python:3.9.25-slim-bookworm@sha256:a02e9c5406c416c504d6c9a1a306ff4080c3173f1008d192f953bd20382a2d5c

# add apache bench (ab) tool
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    apache2-utils \
    && rm -rf /var/lib/apt/lists/*

# Create an unprivileged user to run the application
RUN groupadd --gid 10001 app && \
    useradd --uid 10001 --gid app --create-home --shell /usr/sbin/nologin app

WORKDIR /seed

COPY --chown=app:app . .
RUN chown -R app:app /seed

# Run as an unprivileged user
USER app

# create POST data files with ab friendly formats
RUN python make-data.py

CMD ["/seed/generate-votes.sh"]
