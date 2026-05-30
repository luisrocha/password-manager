# Password Manager

> 🚧 **Work in progress:** This project is actively being built and is not production-ready yet. 🚧

Rails application for a self-hosted password manager.

## Implemented Features
- Client-side vault unlock flow with a 12-hour authenticated web session window
- Browser API unlock flow using signed vault challenges and encrypted JWT bearer tokens
- Encrypted storage of sensitive fields (`username`, `password`, `notes`) using client-side encrypted payloads
- Credential management from the web UI (create, list, edit, delete)
- Search credentials by `name` and `domain`
- Sensitive fields hidden by default in the UI and revealed on demand
- 1Password CSV import support (`Title`, `Website`, `Username`, `Password`, `Notes`, `Category`)

## Requirements
- Ruby `3.4.7`
- Bundler
- SQLite3

## Setup
```bash
bin/setup
```

## Environment
Copy `.env.example` values into your local environment file as needed. Keep real secrets out of git.

Additional browser API environment variables:
- `PASSWORD_MANAGER_BROWSER_JWT_TTL_SECONDS` (optional, default `900`)
- `PASSWORD_MANAGER_API_TOKEN` (required by `POST /api/browser/auth/unlock`)

## Run
```bash
bin/rails server
```

## Run With Docker Compose
The primary Compose file runs Rails in production mode behind Caddy, which serves
HTTPS locally and redirects HTTP to HTTPS.

1. Add the default host to your machine:
   ```bash
   sudo sh -c 'echo "127.0.0.1 vault.localhost" >> /etc/hosts'
   ```
2. Copy `docker-compose.env.example` values into `docker-compose.env` or `.env` and replace the
   placeholders. Generate `SECRET_KEY_BASE` with:
   ```bash
   bin/rails secret
   ```
3. Start the app:
   ```bash
   docker compose up --build
   ```
4. Open:
   ```text
   https://vault.localhost
   ```

Change `PASSWORD_MANAGER_HOST` in `.env` to use a different local host name.
Caddy uses an internal certificate authority, so your browser may ask you to
trust the local certificate before the page opens cleanly.

To trust the local Caddy certificate authority on the host machine:
```bash
bin/trust-local-caddy-ca
```

Then restart your browser. Firefox may still require importing
`tmp/certs/password-manager-local-root.crt` manually in:
`Settings -> Privacy & Security -> Certificates -> View Certificates`.

## Test
```bash
bin/rails test
```
