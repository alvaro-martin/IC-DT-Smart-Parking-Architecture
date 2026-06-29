# SSL Certificates for NGINX Reverse Proxy

This directory contains **example** SSL certificates for development/testing.
For production, generate your own certificates using your domain name.

## Generate a Self-Signed Certificate

Use the `DOMAIN_NAME` value from your `.env` file:

```bash
# 1. Load your domain name from .env
source ../.env

# 2. Generate the certificate (valid for 365 days)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout grafana.key -out grafana.crt \
  -subj "/CN=${DOMAIN_NAME}"
```

## Files

- `grafana.crt` — Example SSL certificate (localhost)
- `grafana.key` — Example SSL private key
