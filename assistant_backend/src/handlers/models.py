"""
Shared normalised intermediate format returned by all handlers.
"""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class UnitDraft:
    title: str
    order_index: int
    estimated_minutes: int | None  # None = pending LLM estimation


@dataclass
class ResourceStructure:
    title: str
    type: str                         # github_repo | bilibili_series | pdf | web_article
    tracking_mode: str                # sequential | pool
    url: str
    units: list[UnitDraft] = field(default_factory=list)
    total_estimated_hours: float = 0.0  # computed after LLM estimation fills nulls
