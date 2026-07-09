# SSL Certificates for NGINX Reverse Proxy

This directory contains **example** SSL certificates for development/testing.
For production, generate your own certificates using your domain name.

## Setup

The certificate generation script reads `DOMAIN_NAME` from your `.env` file.
If you do not have one yet, create it from the template:

```bash
# 1. Copy the environment template (do this once, the first time)
cp ../.env.example ../.env

# 2. Edit ../.env and set DOMAIN_NAME to your own domain
```

The `.env` file is gitignored — **never commit it** to version control.

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
