import os
import signal
import asyncio
from contextlib import asynccontextmanager, suppress
from collections.abc import Callable, Mapping

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .db.init import init_db

load_dotenv()

DB_PATH = os.getenv("DB_PATH", "learning.db")
PORT = int(os.getenv("PORT", "8765"))

scheduler = AsyncIOScheduler()


class ParentProcessMonitor:
    def __init__(
        self,
        expected_parent_pid: int,
        get_parent_pid: Callable[[], int],
        request_shutdown: Callable[[], None],
        poll_interval_seconds: float = 1.0,
    ) -> None:
        self.expected_parent_pid = expected_parent_pid
        self._get_parent_pid = get_parent_pid
        self._request_shutdown = request_shutdown
        self._poll_interval_seconds = poll_interval_seconds

    async def poll_once(self) -> bool:
        if self._get_parent_pid() != self.expected_parent_pid:
            self._request_shutdown()
            return False
        return True

    async def run(self) -> None:
        while await self.poll_once():
            await asyncio.sleep(self._poll_interval_seconds)


def _request_graceful_shutdown() -> None:
    os.kill(os.getpid(), signal.SIGTERM)


def _build_parent_monitor_from_env(
    env: Mapping[str, str] = os.environ,
    get_parent_pid: Callable[[], int] = os.getppid,
    request_shutdown: Callable[[], None] = _request_graceful_shutdown,
    poll_interval_seconds: float = 1.0,
) -> ParentProcessMonitor | None:
    expected_parent_pid = env.get("MALDAZE_PARENT_PID")
    if expected_parent_pid is None:
        return None

    return ParentProcessMonitor(
        expected_parent_pid=int(expected_parent_pid),
        get_parent_pid=get_parent_pid,
        request_shutdown=request_shutdown,
        poll_interval_seconds=poll_interval_seconds,
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db(DB_PATH)

    from .routers import (
        ingest,
        morning,
        chat,
        review,
        study_plan,
        study_views,
        resources as resources_router,
        tasks as tasks_router,
        settings as settings_router,
    )
    app.include_router(ingest.router, prefix="/api")
    app.include_router(morning.router, prefix="/api")
    app.include_router(chat.router, prefix="/api")
    app.include_router(review.router, prefix="/api")
    app.include_router(study_plan.router, prefix="/api")
    app.include_router(study_views.router, prefix="/api")
    app.include_router(resources_router.router, prefix="/api")
    app.include_router(tasks_router.router, prefix="/api")
    app.include_router(settings_router.router, prefix="/api")

    _register_scheduler_jobs()
    scheduler.start()
    parent_monitor = _build_parent_monitor_from_env()
    parent_monitor_task = None
    if parent_monitor is not None:
        parent_monitor_task = asyncio.create_task(parent_monitor.run())

    try:
        yield
    finally:
        if parent_monitor_task is not None:
            parent_monitor_task.cancel()
            with suppress(asyncio.CancelledError):
                await parent_monitor_task

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
