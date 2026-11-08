import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, text

from app.errors import register_error_handlers

DATABASE_URL = os.environ["DATABASE_URL"]
engine = create_engine(DATABASE_URL, pool_pre_ping=True)

app = FastAPI(title="Defne Family Clinic API")
register_error_handlers(app)  # one error format for every endpoint

# The browser (Next.js on port 3000) may call this API directly.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    """Checks that the API can reach the database."""
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    return {"status": "ok"}


@app.get("/services")
def list_services():
    """Active services. Proves the seed data is loaded."""
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT id, name, duration_minutes "
                "FROM services WHERE active ORDER BY name"
            )
        ).mappings().all()
    return [dict(r) for r in rows]
