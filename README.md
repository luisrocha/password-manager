# Password Manager

> 🚧 **Work in progress:** This project is actively being built and is not production-ready yet. 🚧

Rails application for a self-hosted password manager.

## Implemented Features
- Client-side vault unlock flow with a configurable authenticated web session window
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
- Docker and Docker Compose, for containerized production-like, development, and test runs

## Usage

### Environment
Copy `.env.example` values into your local environment file as needed. Keep real secrets out of git.

Additional browser API environment variables:
- `PASSWORD_MANAGER_SETUP_TOKEN` (required before the first vault key is registered; first setup is rejected if this is missing or left as the example placeholder)
- `PASSWORD_MANAGER_VAULT_SESSION_TTL_MINUTES` (optional web session duration after unlock, default `30`)
- `PASSWORD_MANAGER_BROWSER_JWT_TTL_SECONDS` (optional, default `900`)
- `PASSWORD_MANAGER_API_TOKEN_SHA256_HASHES` (required by `POST /api/browser/auth/unlock` when using the browser extension API; comma-separated hashes allow token rotation)

For the browser extension API bootstrap token, generate a high-entropy token,
store the token itself only in the extension, and configure the server with the
token's SHA-256 hash.

### Run With Docker Compose
The primary Compose file runs Rails in production mode behind Caddy, which serves
HTTPS locally and redirects HTTP to HTTPS.

1. Copy `docker-compose.env.example` values into `docker-compose.env` or `.env` and replace the
   placeholders. Generate `SECRET_KEY_BASE` with:
   ```bash
   bin/rails secret
   ```
2. Start the app:
   ```bash
   docker compose up --build
   ```
3. Open:
   ```text
   https://vault.localhost
   ```

`vault.localhost` should resolve to `127.0.0.1` on modern systems without an
`/etc/hosts` entry. If your machine does not resolve it, either add a hosts
entry or change `PASSWORD_MANAGER_HOST` to another local host name.

Caddy uses an internal certificate authority, so your browser may ask you to
trust the local certificate before the page opens cleanly. To trust the local
Caddy certificate authority on the host machine:

```bash
bin/trust-local-caddy-ca
```

Then restart your browser. Firefox may still require importing
`tmp/certs/password-manager-local-root.crt` manually in:
`Settings -> Privacy & Security -> Certificates -> View Certificates`.

### Vault Backups
The vault backup file contains encrypted private key material. Store it somewhere
safe and separate from the app server. Anyone who obtains the backup can attempt
an offline attack against the master password, so use a long, unique master
password or passphrase.

## Development

### Running the app locally
```bash
bin/setup
bin/rails server
```

Then open `http://localhost:3000`.

### Running the development app in Docker
```bash
docker compose build dev
docker compose run --rm dev bin/rails db:prepare
docker compose --profile dev up dev
```

Then open `http://localhost:3000`.

### Running tests locally
```bash
bin/rails test
bin/rails test:system
```

### Running tests in Docker
The `tests` and `system-tests` services reuse the development image, so one
build is enough for both.

```bash
docker compose build dev
docker compose run --rm tests
docker compose run --rm system-tests
```
