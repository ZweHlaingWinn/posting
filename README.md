# Social Scheduler

Schedule and publish posts across multiple social platforms, with per-post
analytics.

- `backend/` — Rails 7 API-only, PostgreSQL, Sidekiq/Redis
- `frontend/` — Vue 3, Vite, Pinia, Vue Router, Axios

## Status

**Phase 1 (Foundation) complete.** Authentication, background job infrastructure
and the frontend shell are in place. Social account connections, posting,
scheduling and analytics are later phases.

## Requirements

| Dependency | Version used |
| ---------- | ------------ |
| Ruby       | 3.2.0        |
| Rails      | 7.1.6        |
| PostgreSQL | 17           |
| Redis      | 8            |
| Node.js    | 26           |

## Backend setup

```bash
cd backend
cp .env.example .env          # then fill in real values
bundle install
bin/rails db:create db:migrate
bin/rails db:seed             # creates a development login (see below)
bin/rails server              # http://localhost:3000
```

`db:seed` creates `dev@example.com` / `password123` for local sign-in. Override
with `SEED_USER_EMAIL` and `SEED_USER_PASSWORD`; the seed is skipped outside the
development environment.

Run the background worker in a second shell:

```bash
cd backend
bundle exec sidekiq -C config/sidekiq.yml
```

Run the test suite:

```bash
cd backend
bundle exec rspec
```

## Deploy the backend on Render

Infrastructure is declared in `render.yaml` at the repo root: a Rails web
service, a Sidekiq worker, Postgres, and a Redis-compatible Key Value store.

1. Push this repo to GitHub, GitLab, or Bitbucket.
2. In the [Render Dashboard](https://dashboard.render.com), go to **Blueprints →
   New Blueprint Instance** and select the repo.
3. Apply the Blueprint. Render generates `SECRET_KEY_BASE`, the JWT secret, and
   Active Record encryption keys. Do not rotate those encryption keys later or
   existing social-account tokens become unreadable.
4. After the first deploy, open the `social-scheduler-settings` environment
   group and set `FRONTEND_URL` and `CORS_ALLOWED_ORIGINS` to your SPA origin
   (comma-separated if you need more than one).
5. Optional: add SMTP vars (`SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`,
   `SMTP_PASSWORD`) so password-reset mail is actually delivered. Add OAuth
   client IDs/secrets to the same group when you connect platforms.

The API is healthy at `GET /up`. OAuth callback URLs use the Render hostname
automatically (`https://<service>.onrender.com/api/v1/oauth/<platform>/callback`)
unless you set `BACKEND_URL`.

## Frontend setup

```bash
cd frontend
cp .env.example .env.local
npm install
npm run dev                   # http://localhost:5173
```

## API

All endpoints are versioned under `/api/v1`. Successful responses return the
resource directly; failures return `{ "errors": ["..."] }`.

| Method   | Path                | Purpose                          | Auth |
| -------- | ------------------- | -------------------------------- | ---- |
| `POST`   | `/auth/signup`      | Register, returns a JWT          | No   |
| `POST`   | `/auth/login`       | Sign in, returns a JWT           | No   |
| `DELETE` | `/auth/logout`      | Revoke the caller's tokens       | Yes  |
| `POST`   | `/auth/password`    | Email password reset instructions| No   |
| `PUT`    | `/auth/password`    | Redeem reset token, set password | No   |

Authenticated requests send `Authorization: Bearer <token>`.

## Architecture notes

- **Thin controllers.** Controllers parse params, call a service object under
  `app/services/`, and render the resulting `ServiceResult`. Business rules live
  in the services.
- **JWT revocation.** Uses devise-jwt's `JTIMatcher`: each user row holds a
  `jti`, and rotating it invalidates every token issued to that user. Logout and
  password reset both rotate it.
- **Account enumeration.** Login and password-reset responses are deliberately
  identical whether or not the email is registered.
- **Secrets.** Read from `ENV` only. `.env.example` documents every variable with
  placeholder values; real `.env` files are gitignored.
