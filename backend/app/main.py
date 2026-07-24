from fastapi import FastAPI

from app.api.bookings import router as bookings_router

app = FastAPI(title="Barbershop API")
app.include_router(bookings_router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
