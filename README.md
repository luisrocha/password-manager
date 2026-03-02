# Password Manager

> 🚧 **Work in progress:** This project is actively being built and is not production-ready yet. 🚧

Rails application for a self-hosted password manager.

## Implemented Features
- Master-password gate for all web access
- Unlock/lock flow with a 12-hour authenticated web session window
- Browser API unlock flow using master password + encrypted JWT bearer token
- Encrypted storage of sensitive fields (`username`, `password`, `notes`) using Active Record Encryption
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

Set your master password:
- MASTER_PASSWORD (required)

Additional browser API environment variables:
- `PASSWORD_MANAGER_BROWSER_JWT_TTL_SECONDS` (optional, default `900`)
- `PASSWORD_MANAGER_API_TOKEN` (required by `POST /api/browser/auth/unlock`)

## Run
```bash
bin/rails server
```

## Test
```bash
bin/rails test
```

