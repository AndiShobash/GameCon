FROM python:3.11-alpine AS builder
WORKDIR /app
COPY requirements.txt .
RUN apk add --no-cache --virtual .build-deps gcc musl-dev postgresql-dev \
    && pip install --no-cache-dir -r requirements.txt \
    && apk del .build-deps

FROM python:3.11-alpine
WORKDIR /app

# Install runtime dependencies (removed curl for health check simplification)
RUN apk add --no-cache postgresql-libs netcat-openbsd

# Copy installed packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

COPY app app
COPY templates templates
COPY entrypoint.sh .

RUN chmod +x entrypoint.sh \
    && adduser -D -H appuser \
    && chown -R appuser:appuser /app

USER appuser
EXPOSE 5000
ENTRYPOINT ["./entrypoint.sh"]