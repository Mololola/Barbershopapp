# Barbershop App

Two-sided marketplace: customers book barbershop appointments, shops manage bookings/staff/services. Full product vision lives in [`docs/product-spec.docx`](docs/product-spec.docx); the derived technical plan is in [`docs/architecture.md`](docs/architecture.md) — read that first for the client/backend split, the booking-concurrency design, and the Phase 1 vs Phase 2+ roadmap.

**Currently preparing for launch** (UK and Spain, Android and iOS together; work on the `launch-prep` branch, taken from master). Built: auth, profiles, services, booking engine, reviews, feed, messages, rankings, review and referral rewards with payouts, shop subscriptions and Finance Premium (Stripe), and the 3D haircut designer, which is **paused and hidden** (`designerEnabled = false` in `mobile/lib/core/router.dart`; don't work on it or turn it on unless the user asks). Paid services (Supabase/Render plans, Stripe live, Apple, domains) are switched on last, each with the user's OK.

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

**Business website** (the same Flutter app, built for the browser — see "Business website" in `docs/architecture.md`)
```bash
cd mobile
flutter run -d chrome --web-port 8766 --dart-define-from-file=env.json   # needs WEB_APP_URL=http://localhost:8766 in backend/.env
```

Neither `.env` nor `env.json` is committed — only the `.example` files are.

## Conventions

- New backend endpoints live under `backend/app/api/`; DB models under `backend/app/models/`; settings/config under `backend/app/core/`. Migrations via Alembic (`backend/alembic/`), configured to read `DATABASE_URL` from `app/core/config.py`, not `alembic.ini`.
- Backend dependencies are pinned in `backend/requirements.txt` (prod) and `backend/requirements-dev.txt` (+ test deps), compiled from `backend/pyproject.toml` via `pip-compile` (pip-tools) — `pyproject.toml`'s `>=` ranges are the source of truth, the `requirements*.txt` files are the reproducible, committed lock. After changing a dependency in `pyproject.toml`, regenerate both (`pip-compile -o requirements.txt pyproject.toml` and `pip-compile --extra dev -o requirements-dev.txt pyproject.toml`) and re-run `pip-sync requirements-dev.txt` locally.
- New Flutter screens/logic are organized by feature under `mobile/lib/features/<feature>/`; cross-cutting app setup (env, router) lives in `mobile/lib/core/`.
- Screens must work at phone width and on the wide (website/tablet) layout: check `isWideLayout(context)` / use `ResponsiveColumns` from `mobile/lib/core/responsive.dart` rather than hardcoding a phone-only layout, and keep the phone layout unchanged when adding a wide one.
- The booking table must keep its Postgres `EXCLUDE` constraint (see `docs/architecture.md`) as the source of truth for "no double-booking" — never rely on app-level check-then-insert alone for that guarantee.
- [Graphify](https://github.com/Graphify-Labs/graphify) is installed for codebase-graph navigation (`graphify-out/`, gitignored/regenerable). Re-run `graphify update .` after structural changes if you want the graph current; not required for day-to-day edits.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

## 3D haircut designer: lead-engineer brief

Applies to all work on the 3D haircut designer (`mobile/assets/haircut_designer/`, `mobile/lib/features/designer/`). The detailed state, flow and architecture are in `HANDOFF-designer.md`.

### Role
You are the lead engineer for the 3D haircut designer inside the barbershop app (Fadra Cut). The goal: make the designer look and move at the quality of two reference products, while running at 45+ fps on a Samsung Galaxy A33. Work in small, verifiable patches. Never rewrite working parts.

### References (what to take, what never to take)
1. **Digital Salon** (Adobe Research et al.). Code is MIT: https://github.com/digital-salon/Digital-Salon . Paper: https://arxiv.org/abs/2507.07387
   - Take the ideas:
     - strand-level mass-spring physics (edge, bending, torsion, plus two extra one-way springs for global shape);
     - hair-hair interaction;
     - procedural strand growth for beards (its defaults: p_Γ=0.2, p_Ω=0.3, p_freq=1.0);
     - grooming by removing particles and their springs;
     - text-to-hairstyle retrieval over a captioned library.
   - Its code is C++/CUDA and will not run on a phone: port the ideas, not the code. If code is closely adapted, keep the MIT notice and cite the paper. Its head mesh and Adobe's videos and data are not reusable.
2. **Reallusion Smart Hair**, proprietary: https://www.reallusion.com/character-creator/hair.html
   - Take only what the public page describes:
     - card-based hair;
     - the component split (base, top, rear, bangs, accessory);
     - shader controls for root/end ombré, highlight (balayage) colour, and flow-map specular direction.
   - Never decompile, unpack, or copy its code, shaders, meshes or textures.
   - To match its motion, use black-box measurement only:
     - the user records their own reference clips;
     - measure sway frequency (Hz), tip-vs-root lag (ms), and settling time after a force stops;
     - tune our parameters until our numbers are within 10% of those.

### Current state (verify it first, do not assume)
- **Paused since 28 Oct 2026 and hidden** (`designerEnabled = false`), merged into master at `60dbaee`. Resume only when the user asks; `HANDOFF.md` has the full state.
- **Every patch must keep** the analyzer clean, all tests passing, and the designer JS passing `node --check`.
- **Done and confirmed on the A33:** physics (45–53 fps), mannequin head, hair types 1A–4C, Barber detail, brushes, mirror, undo/redo, 26 cuts (all checked), colour tools (ombré, highlights, balayage, shine angle), long hair on the shoulders, the afro hairline, the receding hairline, beard and brow presets with a profile trim.
- **Item 5 left unfinished:** the Grow beard brush and its length slider exist; the Shave brush and brow painting don't.
- **Flow:** Designs tab (My Designs, Browse) → Editor (3D head + tabs: Cut, Shape with Barber detail, Tools, Colour, Motion) → Save (name, public or private, thumbnail). Free limit 3 designs, +2 slots for £2. Browse lets people view public designs and Fork them.
- **Purpose:** a personal library of several saved designs that the customer shows on their phone when they get to the shop. Designs are deliberately **not** attached to bookings or sent in messages. The user decided against that feature, so don't propose or build it.
- **Speed:** about 30 ms GPU per frame at full quality against a 22 ms budget; the user has their own solution in mind, so don't start it unasked.

### When work resumes, propose in this order
1. delete/rename designs;
2. Browse search/filters;
3. Designs screen restyle;
4. "Describe your cut" (retrieval over cut names and descriptions, server-side);
5. optional AI photoreal image (server-side, with a cost note);
6. braids and locs;
7. updating the technical doc.

### Acceptance checks for the 10 new cuts
For each cut, ask the user for a front, side and back screenshot taken on the A33, and judge against these:

| Cut | Must show |
|---|---|
| Man Bun | Hair gathered into one mass at the crown and tied, with no loose strands crossing the face, and the sides tight to the head. |
| Low Ponytail | Tied at the nape, falling straight down the back with natural sway; it must not penetrate the neck or shoulders. |
| French Crop, Caesar | Short and even, a forward fringe of consistent length, tight sides. |
| Side Part, Slicked Side Part | A visible part line, hair flowing in one direction, and no gaps showing scalp at the part. |
| Wavy Air-Dry, Wavy Long Layers, Shag | A visible wave pattern, layered lengths, volume at the crown. |
| Long Slicked Back | A smooth back-combed flow from the hairline, with no loose ends sticking out. |

For every failure, state the likely cause, the exact file and function, and the fix.

### Physics rules (tune the existing system; do not replace it)
- Simulate guide strands only, then interpolate to the rendered strands or cards. Keep the current count unless frame time allows more.
- **The model:**
  - fixed timestep of 1/60 s with 2–4 substeps;
  - roots pinned to the scalp;
  - distance constraints keep segment length constant;
  - bending constraints add stiffness;
  - damping so hair settles;
  - gravity and a wind force field;
  - head and shoulder collision with spheres or capsules.
- **Long hair splaying sideways on the shoulders:** check the shoulder collision shapes and friction first, then bending stiffness at the lower segments, then damping.
- **Budget:** total frame time under 22 ms (45+ fps) on the A33. Measure before and after every change and report both numbers.

### Shading rules
- Anisotropic specular along the strand tangent (Kajiya-Kay style), with a controllable flow offset.
- Root-to-tip gradient through a root map; highlight colour through an ID map. No gradients that need per-frame textures if the A33 can't afford them.
- **Jagged afro hairline:** look at the hairline root distribution, alpha cutout vs alpha blending, and the baby-hair or scalp-patch idea (soft, short, low-opacity hair around the hairline), not just anti-aliasing.

### Delivery protocol
- **First message of any session:** run the analyzer and the test suite, report the counts, and list the files touched by the last commit.
- **One change at a time.** For each one, give:
  - the file and function;
  - the exact patch;
  - the value-by-value reasoning with real numbers (for example "constraint iterations 2 → 4, stiffness 0.7 → 0.9, expected frame time +1.5 ms");
  - what the user should look at on screen;
  - the measurable expected result.
- **After each patch:**
  - the analyzer is clean, all tests still pass, and the JS syntax check passes;
  - fps is measured on the A33;
  - a test is added or updated when behaviour changes.
- **Commits:** commit locally in small commits with clear messages.
- **Never** push, merge to master, or touch billing code (the 3 free designs + £2 slots) without the user's explicit yes.
- If asked for something that would copy proprietary code, assets or data, say so and offer the independent-implementation route.
- If a screenshot or clip is needed to judge visual quality, ask for it. Do not claim a cut "looks right" without seeing it.
- Keep a short running log at the end of each reply: **Done, Verified, Next.**
