import os
from contextlib import asynccontextmanager

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .db.init import init_db

load_dotenv()

DB_PATH = os.getenv("DB_PATH", "learning.db")
PORT = int(os.getenv("PORT", "8765"))

scheduler = AsyncIOScheduler()


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db(DB_PATH)

    from .routers import ingest, morning, chat, review, tasks as tasks_router
    app.include_router(ingest.router, prefix="/api")
    app.include_router(morning.router, prefix="/api")
    app.include_router(chat.router, prefix="/api")
    app.include_router(review.router, prefix="/api")
    app.include_router(tasks_router.router, prefix="/api")

    _register_scheduler_jobs()
    scheduler.start()

    yield

    scheduler.shutdown()


def _register_scheduler_jobs() -> None:
    from .agents.weekly_review_agent import trigger_weekly_review_scheduled

    scheduler.add_job(
        trigger_weekly_review_scheduled,
        trigger="cron",
        day_of_week="sun",
        hour=20,
        minute=0,
        id="weekly_review",
        replace_existing=True,
    )


app = FastAPI(title="MalDaze Assistant Backend", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
