# base defines a base stage that uses the official python runtime base image
FROM python:3.11.17-slim-bookworm@sha256:f06d01d4ba3f8ad5af45a3ec87df19c1d317d8e8961edc0fabda61811af6f7cf AS base

# Add curl for healthcheck
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Create an unprivileged user to run the application
RUN groupadd --gid 10001 app && \
    useradd --uid 10001 --gid app --create-home --shell /usr/sbin/nologin app

# Set the application directory
WORKDIR /usr/local/app

# Install our requirements.txt
COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

RUN chown -R app:app /usr/local/app

# dev defines a stage for development, where it'll watch for filesystem changes
FROM base AS dev
RUN pip install watchdog
ENV FLASK_ENV=development
USER app
CMD ["python", "app.py"]

# final defines the stage that will bundle the application for production
FROM base AS final

# Copy our code from the current folder to the working directory inside the container
COPY --chown=app:app . .

# Make port 8080 available for links and/or publish
EXPOSE 8080

# Run as an unprivileged user
USER app

# Define our command to be run when launching the container
CMD ["gunicorn", "app:app", "-b", "0.0.0.0:8080", "--log-file", "-", "--access-logfile", "-", "--workers", "4", "--keep-alive", "0"]
