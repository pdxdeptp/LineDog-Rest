"""
Shared normalised intermediate format returned by all handlers.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal


PreviewCalibration = Literal["low", "medium", "high"]
PreviewFetchStatus = Literal["available", "partial", "unavailable"]
CanonicalRepoRole = Literal[
    "main_learning_object",
    "reference_source",
    "clone_rebuild_target",
    "project_material",
    "later_reading",
]


@dataclass
class UnitDraft:
    title: str
    order_index: int
    estimated_minutes: int | None  # None = pending LLM estimation
    is_synthetic: bool = False
    calibration: PreviewCalibration | None = None


@dataclass
class ResourceStructure:
    title: str
    type: str                         # github_repo | bilibili_series | pdf | web_article
    tracking_mode: str                # sequential | pool
    url: str
    units: list[UnitDraft] = field(default_factory=list)
    total_estimated_hours: float = 0.0  # computed after LLM estimation fills nulls


@dataclass
class GitHubPreview:
    title: str
    source_type: str
    url: str
    description: str | None = None
    readme_outline: list[str] = field(default_factory=list)
    topics: list[str] = field(default_factory=list)
    coarse_directory_signals: list[str] = field(default_factory=list)
    fetch_status: PreviewFetchStatus = "unavailable"
    calibration: PreviewCalibration = "low"
    canonical_repo_role: CanonicalRepoRole | None = None
