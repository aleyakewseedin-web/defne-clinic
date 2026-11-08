# Defne Family Clinic: starter project (Week 1)

Next.js (React + TypeScript) front end, FastAPI back end, PostgreSQL database.

## Run it

Requires Docker Desktop.

    docker compose up --build

Then open:

- http://localhost:3000       the Next.js app (shows the seeded services)
- http://localhost:8000/docs  the FastAPI interactive docs
- http://localhost:8000/health  API and database check

## Seed users (password for all: password123)

| Role          | Email                |
|---------------|----------------------|
| Administrator | admin@defne.test     |
| Staff         | staff@defne.test     |
| Customer      | customer@defne.test  |

## Reset the database

The schema and seed data load only the first time. To start fresh:

    docker compose down -v
    docker compose up --build

## Layout

    db/init.sql      schema, the overlap constraint, seed data
    backend/app      FastAPI (main.py has /health and /services)
    frontend/app     Next.js App Router (layout.tsx, page.tsx)

## Next steps (Weeks 2-3)

Booking, reschedule and cancel endpoints, and the concurrency test
(two simultaneous requests for one slot: exactly one succeeds).

## Error format (every endpoint)

    { "code": "slot_taken", "message": "This time is already taken for that staff member." }

With form problems, a `fields` list is added:

    { "code": "validation_failed", "message": "Please correct the highlighted fields.",
      "fields": [{ "field": "phone", "message": "Enter a valid phone number." }] }

Raise `ApiError` (backend/app/errors.py) in the API; use `apiFetch` (frontend/lib/api.ts) in Next.js.
