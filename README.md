# SmileRecruit — Candidate Onboarding

A candidate-onboarding platform for dental-industry recruitment: candidates upload a CV, get an AI-prefilled profile to review and complete, and recruiters see submitted profiles in an admin dashboard.

**Working on this codebase?** See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the domain model, request flows (with diagrams), the CV-extraction fallback chain, and the auth design — this README only covers setup.

## Stack

- Rails 8.1.3 / Ruby 3.3.7
- MySQL (via `mysql2`)
- Bootstrap 5.3.3 (vendored locally, no CDN) + Hotwire (Turbo + Stimulus)
- Devise for authentication (two separate scopes — see below)
- Active Storage (local disk) for CV file uploads

## Features

- **CV upload** (PDF/DOC/DOCX, up to 25MB by default — see `CV_MAX_FILE_SIZE_MB`) with drag-and-drop, in any language.
- **Three-tier extraction fallback**, tried in order per upload:
  1. Claude (`CvExtractionService`) if `ANTHROPIC_API_KEY` is set
  2. Google Gemini (`GeminiCvExtractionService`) if `GEMINI_API_KEY` is set — includes automatic retry with backoff for transient `429`/`5xx` errors (the free tier does this under load)
  3. `RegexCvExtractor` — a dependency-free fallback (name/email/phone only) so the form is never left completely blank when no AI key is configured
- **Profile review form** with conditional fields (BIG registration, salary vs. percentage-based compensation, average daily revenue) driven by job function and employment type, plus repeatable Education and Work Experience sections.
- **Two separate Devise-authenticated account types**:
  - `User` — candidates. Login, self-registration, and logout (`/users/sign_up`, `/users/sign_in`). Each user has at most one `candidate_profile`; the whole onboarding flow requires being signed in, and a user can only ever see their own profile.
  - `AdminUser` — recruiters. Login/logout only, **no self-registration** (provisioned via `db/seeds.rb` or the Rails console) — see `AdminUser` for why. Gates the `/admin` namespace.
- **Admin dashboard** (`/admin`) listing all submitted candidate profiles, with a detail view per candidate (personal details, education, work experience, skills, CV download).

## Setup

### Prerequisites

- Ruby 3.3.7 (see `.ruby-version`)
- A running MySQL server (this app was developed against MySQL 5.7)

### Install

```bash
bundle install
```

### Configure the database

`config/database.yml` reads credentials from the environment, defaulting to `root`/`root` against `127.0.0.1:3306`:

```bash
export DATABASE_USERNAME=root     # optional, defaults to root
export DATABASE_PASSWORD=root     # optional, defaults to root
export DATABASE_HOST=127.0.0.1    # optional
export DATABASE_PORT=3306         # optional
```

```bash
bin/rails db:create db:migrate db:seed
```

Seeding creates the job functions/skills/languages reference data, and one `AdminUser` (see below).

### Configure AI extraction (optional but recommended)

Copy your key(s) into `.env` at the project root (already gitignored):

```
ANTHROPIC_API_KEY=
GEMINI_API_KEY=
```

Neither is required — without one, every upload falls back to the regex extractor (name/email/phone only; education, work experience, skills, and languages are left for the candidate to fill in manually).

- **Anthropic**: console.anthropic.com
- **Gemini** (has a free tier): aistudio.google.com/apikey → "Create API key"

`dotenv-rails` (development only — tests stub AI calls via WebMock and never touch the real APIs) loads `.env` automatically, so there's no need to `export` these by hand.

### Login credentials (first time)

| | Email | Password | Notes |
|---|---|---|---|
| **Admin** (recruiter) | `admin@example.com` | `password123` | Seeded by `db:seed` — see below to change it. Sign in at `/admin_users/sign_in`. |
| **User** (candidate) | *(none seeded)* | — | No default account — admins can't self-register, but candidates can. Create one yourself at `/users/sign_up`. |

To use different admin credentials, set these **before** running `db:seed`:

```bash
export ADMIN_EMAIL=you@example.com
export ADMIN_PASSWORD=something-else
bin/rails db:seed
```

(`db:seed` is idempotent — re-running it won't create a second admin or reset the password of one that already exists; change the password via the Rails console or the "Forgot your password?" flow instead.)

### Run the app

```bash
bin/rails server
```

Visit `http://localhost:3000` — you'll be redirected to sign in/sign up (candidate flow). Admins sign in separately at `/admin_users/sign_in`, landing on the `/admin` dashboard.

## Testing

```bash
bundle exec rspec       # 149 examples
bundle exec rubocop     # style/lint, via rubocop-rails-omakase
```

Both are expected to be green on `main` at all times.

## Key routes

| Path | Purpose |
|---|---|
| `/` | Candidate: upload CV (redirects to sign in if not authenticated) |
| `/users/sign_up`, `/users/sign_in` | Candidate registration / login |
| `/onboarding/uploads/:access_token` | CV parsing progress ("Analyzing your CV…") |
| `/onboarding/profiles/:access_token/edit` | Review/complete the prefilled profile |
| `/admin_users/sign_in` | Recruiter/admin login |
| `/admin` | Admin dashboard — all candidate profiles |

## Learn more

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the domain model, the candidate onboarding flow, the CV-extraction fallback chain, the auth design (`User` vs `AdminUser`), and a list of sharp edges worth knowing before you touch this code (e.g. why JSON column defaults live on the model, not the migration).
