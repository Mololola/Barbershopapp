# Barbershop App

Two-sided marketplace: customers book barbershop appointments, shops manage bookings/staff/services. Full product vision lives in [`docs/product-spec.docx`](docs/product-spec.docx); the derived technical plan is in [`docs/architecture.md`](docs/architecture.md) — read that first for the client/backend split, the booking-concurrency design, and the Phase 1 vs Phase 2+ roadmap.

**Currently in Phase 1 (MVP)**: auth, business/customer profiles, service catalog, booking engine, reviews, basic post feed. Everything else in the spec (rankings, referral payouts, business finance ML tool, 3D haircut designer, chat) is intentionally deferred — don't build toward those yet without an explicit go-ahead.

## Stack

- **Mobile**: Flutter (`mobile/`) — Riverpod for state, go_router for navigation, supabase_flutter for auth/storage/realtime.
- **Backend**: FastAPI (`backend/`) — owns anything transactional or secret: booking creation, reviews, (later) Stripe billing/webhooks and reward/ranking math.
- **Data**: Supabase (managed Postgres + Auth + Storage + Realtime). The Flutter app talks to Supabase directly for CRUD/auth/storage/realtime, and to the FastAPI service for booking/money/business-rule operations.

## Running locally

**Backend**
```bash
cd backend
source .venv/Scripts/activate   # venv already created
pip install pip-tools
pip-sync requirements-dev.txt   # installs exact pinned deps + test deps from the lock
pip install -e . --no-deps      # installs this project itself, editable
cp .env.example .env            # fill in your Supabase DATABASE_URL etc.
uvicorn app.main:app --reload
```

**Mobile**
```bash
cd mobile
cp env.json.example env.json    # fill in your Supabase URL + anon/publishable key
flutter run --dart-define-from-file=env.json
```

Neither `.env` nor `env.json` is committed — only the `.example` files are.

## Conventions

- New backend endpoints live under `backend/app/api/`; DB models under `backend/app/models/`; settings/config under `backend/app/core/`. Migrations via Alembic (`backend/alembic/`), configured to read `DATABASE_URL` from `app/core/config.py`, not `alembic.ini`.
- Backend dependencies are pinned in `backend/requirements.txt` (prod) and `backend/requirements-dev.txt` (+ test deps), compiled from `backend/pyproject.toml` via `pip-compile` (pip-tools) — `pyproject.toml`'s `>=` ranges are the source of truth, the `requirements*.txt` files are the reproducible, committed lock. After changing a dependency in `pyproject.toml`, regenerate both (`pip-compile -o requirements.txt pyproject.toml` and `pip-compile --extra dev -o requirements-dev.txt pyproject.toml`) and re-run `pip-sync requirements-dev.txt` locally.
- New Flutter screens/logic are organized by feature under `mobile/lib/features/<feature>/`; cross-cutting app setup (env, router) lives in `mobile/lib/core/`.
- The booking table must keep its Postgres `EXCLUDE` constraint (see `docs/architecture.md`) as the source of truth for "no double-booking" — never rely on app-level check-then-insert alone for that guarantee.
- [Graphify](https://github.com/Graphify-Labs/graphify) is installed for codebase-graph navigation (`graphify-out/`, gitignored/regenerable). Re-run `graphify update .` after structural changes if you want the graph current; not required for day-to-day edits.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
