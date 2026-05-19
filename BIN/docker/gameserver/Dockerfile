# OP ETERNAL game server (mock listener, serve mode).
# Build context is the repo root (see BIN/docker-compose.yml).

FROM python:3.12-slim-bookworm

RUN pip install --no-cache-dir cryptography

RUN mkdir -p /app/gameserver /app/assets /logs
COPY BIN/_app/gameserver/opeternal_listener.py /app/gameserver/
COPY BIN/_app/assets/                          /app/assets/

ENV OEL_LOG_DIR=/logs
WORKDIR /app/gameserver

EXPOSE 80 443
CMD ["python", "opeternal_listener.py", "--bind-ip", "0.0.0.0"]
