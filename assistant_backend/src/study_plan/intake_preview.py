"""Add / Initiate-safe material preview helpers."""
from __future__ import annotations

from ..handlers.github_handler import GitHubHandler
from ..handlers.models import GitHubPreview


async def preview_github_repo(url: str, user_hint: str | None = None) -> GitHubPreview:
    """Return shallow GitHub facts without creating schedulable resource units."""
    return await GitHubHandler(url).preview(user_hint=user_hint)
