"""
Bilibili Handler — detects single video / multi-part (分P) / series (合集/ugc_season).
"""
from __future__ import annotations

import re
from urllib.parse import urlparse

import httpx

from .models import ResourceStructure, UnitDraft

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Referer": "https://www.bilibili.com/",
}


def _extract_bvid(url: str) -> str:
    """Extract BVid from URL like https://www.bilibili.com/video/BV1234567890"""
    m = re.search(r"BV[a-zA-Z0-9]+", url)
    if not m:
        raise ValueError(f"Cannot extract BVid from URL: {url}")
    return m.group(0)


async def _fetch_pagelist(client: httpx.AsyncClient, bvid: str) -> list[dict]:
    """Fetch the multi-part page list for a BVid."""
    try:
        resp = await client.get(
            f"https://api.bilibili.com/x/player/pagelist?bvid={bvid}",
            headers=_HEADERS,
            timeout=15,
        )
        if resp.status_code == 200:
            data = resp.json()
            if data.get("code") == 0:
                return data.get("data", [])
    except Exception:
        pass
    return []


async def _fetch_view(client: httpx.AsyncClient, bvid: str) -> dict:
    """Fetch the video view info, which contains ugc_season for series detection."""
    try:
        resp = await client.get(
            f"https://api.bilibili.com/x/web-interface/view?bvid={bvid}",
            headers=_HEADERS,
            timeout=15,
        )
        if resp.status_code == 200:
            data = resp.json()
            if data.get("code") == 0:
                return data.get("data", {})
    except Exception:
        pass
    return {}


class BilibiliHandler:
    """Handle Bilibili video/series URLs."""

    def __init__(self, url: str) -> None:
        self.url = url
        self.bvid = _extract_bvid(url)

    async def fetch(self) -> ResourceStructure:
        async with httpx.AsyncClient() as client:
            pagelist = await _fetch_pagelist(client, self.bvid)
            view = await _fetch_view(client, self.bvid)

        title = view.get("title", self.bvid) if view else self.bvid
        units: list[UnitDraft] = []

        # Try ugc_season (合集) first
        ugc_season = view.get("ugc_season") if view else None
        if ugc_season:
            sections = ugc_season.get("sections", [])
            order = 0
            for section in sections:
                for ep in section.get("episodes", []):
                    ep_title = ep.get("title") or ep.get("arc", {}).get("title", f"P{order+1}")
                    duration_sec = ep.get("arc", {}).get("duration") or ep.get("duration")
                    estimated = int(duration_sec / 60) if duration_sec else None
                    units.append(UnitDraft(
                        title=ep_title,
                        order_index=order,
                        estimated_minutes=estimated,
                    ))
                    order += 1
            if units:
                series_title = ugc_season.get("title", title)
                return ResourceStructure(
                    title=series_title,
                    type="bilibili_series",
                    tracking_mode="sequential",
                    url=self.url,
                    units=units,
                    total_estimated_hours=0.0,
                )

        # Multi-part video (分P)
        if len(pagelist) > 1:
            for page in pagelist:
                part_title = page.get("part") or f"P{page.get('page', len(units)+1)}"
                duration_sec = page.get("duration")
                estimated = int(duration_sec / 60) if duration_sec else None
                units.append(UnitDraft(
                    title=part_title,
                    order_index=page.get("page", len(units) + 1) - 1,
                    estimated_minutes=estimated,
                ))
            return ResourceStructure(
                title=title,
                type="bilibili_series",
                tracking_mode="sequential",
                url=self.url,
                units=units,
                total_estimated_hours=0.0,
            )

        # Single video fallback
        duration_sec = view.get("duration") if view else None
        estimated = int(duration_sec / 60) if duration_sec else None
        units = [UnitDraft(title=title, order_index=0, estimated_minutes=estimated)]
        return ResourceStructure(
            title=title,
            type="bilibili_series",
            tracking_mode="sequential",
            url=self.url,
            units=units,
            total_estimated_hours=0.0,
        )
