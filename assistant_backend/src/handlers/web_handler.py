"""
Web Handler — generic page scraper.

Strategy
--------
1. Fetch page with httpx.
2. Parse with BeautifulSoup, extract h2/h3 headings as units.
3. If fewer than 2 headings found, call Gemini LLM to extract chapter structure
   from the page body text.
"""
from __future__ import annotations

import json
import re

import httpx
from bs4 import BeautifulSoup

from ..config import GEMINI_API_KEY, GEMINI_MODEL
from .models import ResourceStructure, UnitDraft

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    )
}


async def _fetch_html(url: str) -> str:
    async with httpx.AsyncClient(follow_redirects=True, headers=_HEADERS) as client:
        resp = await client.get(url, timeout=20)
        resp.raise_for_status()
        return resp.text


def _extract_headings(html: str) -> list[str]:
    soup = BeautifulSoup(html, "html.parser")
    headings: list[str] = []
    for tag in soup.find_all(["h1", "h2", "h3"]):
        text = tag.get_text(strip=True)
        if text:
            headings.append(text)
    return headings


def _extract_title(html: str) -> str:
    soup = BeautifulSoup(html, "html.parser")
    # <title>
    if soup.title and soup.title.string:
        return soup.title.string.strip()
    # First <h1>
    h1 = soup.find("h1")
    if h1:
        return h1.get_text(strip=True)
    return "Web Article"


def _extract_body_text(html: str, max_chars: int = 8000) -> str:
    soup = BeautifulSoup(html, "html.parser")
    for tag in soup(["script", "style", "nav", "footer", "header"]):
        tag.decompose()
    return soup.get_text(separator="\n", strip=True)[:max_chars]


async def _llm_extract_chapters(body_text: str, page_title: str) -> list[UnitDraft]:
    """Ask Gemini to extract chapter/section structure from body text."""
    from langchain_google_genai import ChatGoogleGenerativeAI

    llm = ChatGoogleGenerativeAI(
        model=GEMINI_MODEL,
        google_api_key=GEMINI_API_KEY,
        temperature=0,
    )
    prompt = (
        f"You are analysing a web page titled '{page_title}'.\n\n"
        "Extract an ordered list of chapters, sections, or topics from the text below. "
        "Return a JSON array of objects with keys 'title' (string) and 'estimated_minutes' (integer or null). "
        "If the page is a single article with no clear chapters, return a single-item array with the page title.\n\n"
        f"Page text:\n{body_text}\n\n"
        "Respond ONLY with a JSON array, no extra text."
    )
    response = await llm.ainvoke(prompt)
    raw = response.content.strip()
    raw = re.sub(r"^```[a-z]*\n?", "", raw)
    raw = re.sub(r"\n?```$", "", raw)
    items: list[dict] = json.loads(raw)
    return [
        UnitDraft(
            title=item.get("title", f"Section {i+1}"),
            order_index=i,
            estimated_minutes=item.get("estimated_minutes"),
        )
        for i, item in enumerate(items)
    ]


class WebHandler:
    """Handle generic web article / tutorial page URLs."""

    def __init__(self, url: str) -> None:
        self.url = url

    async def fetch(self) -> ResourceStructure:
        try:
            html = await _fetch_html(self.url)
        except Exception as exc:
            # Network failure — single-unit fallback
            return ResourceStructure(
                title=self.url,
                type="web_article",
                tracking_mode="sequential",
                url=self.url,
                units=[UnitDraft(title=self.url, order_index=0, estimated_minutes=None)],
                total_estimated_hours=0.0,
            )

        page_title = _extract_title(html)
        headings = _extract_headings(html)

        units: list[UnitDraft] = []

        if len(headings) >= 2:
            units = [
                UnitDraft(title=h, order_index=i, estimated_minutes=None)
                for i, h in enumerate(headings)
            ]
        else:
            # LLM fallback
            try:
                body = _extract_body_text(html)
                units = await _llm_extract_chapters(body, page_title)
            except Exception:
                units = [UnitDraft(title=page_title, order_index=0, estimated_minutes=None)]

        return ResourceStructure(
            title=page_title,
            type="web_article",
            tracking_mode="sequential",
            url=self.url,
            units=units,
            total_estimated_hours=0.0,
        )
