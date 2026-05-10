import pytest


def _monitor_factory():
    from src import main

    factory = getattr(main, "_build_parent_monitor_from_env", None)
    assert callable(factory), "backend should expose a parent monitor factory"
    return factory


def test_no_maldaze_parent_pid_disables_parent_monitor():
    factory = _monitor_factory()

    monitor = factory(
        env={},
        get_parent_pid=lambda: 123,
        request_shutdown=lambda: None,
    )

    assert monitor is None


@pytest.mark.asyncio
async def test_expected_parent_still_present_keeps_monitor_running():
    factory = _monitor_factory()
    shutdown_requests = []

    monitor = factory(
        env={"MALDAZE_PARENT_PID": "123"},
        get_parent_pid=lambda: 123,
        request_shutdown=lambda: shutdown_requests.append("shutdown"),
        poll_interval_seconds=0.01,
    )

    assert monitor is not None

    keep_running = await monitor.poll_once()

    assert keep_running is True
    assert shutdown_requests == []


@pytest.mark.asyncio
async def test_parent_mismatch_requests_graceful_shutdown():
    factory = _monitor_factory()
    shutdown_requests = []

    monitor = factory(
        env={"MALDAZE_PARENT_PID": "123"},
        get_parent_pid=lambda: 456,
        request_shutdown=lambda: shutdown_requests.append("shutdown"),
        poll_interval_seconds=0.01,
    )

    assert monitor is not None

    keep_running = await monitor.poll_once()

    assert keep_running is False
    assert shutdown_requests == ["shutdown"]
