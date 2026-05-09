"""
GitHub Handler — fetches README and directory tree, extracts learning units.

Priority
--------
1. README contains a Table of Contents / chapter list → LLM parse
2. Directory tree has chapters/ or lessons/ sub-dirs → use dir names
3. LLM fallback estimation from repo description
"""
from __future__ import annotations

import base64
import json
import re
from urllib.parse import urlparse

import httpx

from ..config import GEMINI_API_KEY, GEMINI_MODEL
from .models import ResourceStructure, UnitDraft


def _parse_owner_repo(url: str) -> tuple[str, str]:
    """Extract (owner, repo) from a github.com URL."""
    path = urlparse(url).path.strip("/")
    parts = path.split("/")
    if len(parts) < 2:
        raise ValueError(f"Cannot parse owner/repo from URL: {url}")
    return parts[0], parts[1]


async def _fetch_readme(client: httpx.AsyncClient, owner: str, repo: str) -> str:
    """Return decoded README text, or empty string on failure."""
    try:
        resp = await client.get(
            f"https://api.github.com/repos/{owner}/{repo}/readme",
            headers={"Accept": "application/vnd.github+json"},
            timeout=15,
        )
        if resp.status_code == 200:
            data = resp.json()
            content = data.get("content", "")
            encoding = data.get("encoding", "base64")
            if encoding == "base64":
                return base64.b64decode(content).decode("utf-8", errors="replace")
    except Exception:
        pass
    return ""


async def _fetch_tree(client: httpx.AsyncClient, owner: str, repo: str) -> list[dict]:
    """Return list of tree nodes from the default branch."""
    try:
        resp = await client.get(
            f"https://api.github.com/repos/{owner}/{repo}/git/trees/HEAD?recursive=1",
            headers={"Accept": "application/vnd.github+json"},
            timeout=20,
        )
        if resp.status_code == 200:
            return resp.json().get("tree", [])
    except Exception:
        pass
    return []


def _has_toc(readme: str) -> bool:
    """Check if README has a Table of Contents / chapter structure."""
    toc_patterns = [
        r"#+\s*(table\s+of\s+contents|contents|toc)",
        r"##\s+chapter",
        r"##\s+lesson",
        r"##\s+module",
        r"\*\*chapter\s+\d",
        r"\d+\.\s+\[.+?\]\(.+?\)",  # numbered markdown links (common ToC pattern)
    ]
    lower = readme.lower()
    for p in toc_patterns:
        if re.search(p, lower):
            return True
    return False


async def _llm_parse_readme(readme: str, repo_name: str) -> list[UnitDraft]:
    """Ask Gemini to extract ordered learning units from README."""
    from langchain_google_genai import ChatGoogleGenerativeAI

    llm = ChatGoogleGenerativeAI(
        model=GEMINI_MODEL,
        google_api_key=GEMINI_API_KEY,
        temperature=0,
    )
    prompt = (
        f"You are analysing the README of a GitHub repository called '{repo_name}'.\n\n"
        "Extract an ordered list of learning chapters/modules/lessons from the text below. "
        "Return a JSON array of objects with keys 'title' (string) and 'estimated_minutes' (integer or null). "
        "If you cannot estimate minutes reliably, use null.\n\n"
        f"README:\n{readme[:8000]}\n\n"
        "Respond ONLY with a JSON array, no extra text."
    )
    response = await llm.ainvoke(prompt)
    raw = response.content.strip()
    # Strip markdown code fences if present
    raw = re.sub(r"^```[a-z]*\n?", "", raw)
    raw = re.sub(r"\n?```$", "", raw)
    items: list[dict] = json.loads(raw)
    return [
        UnitDraft(
            title=item.get("title", f"Unit {i+1}"),
            order_index=i,
            estimated_minutes=item.get("estimated_minutes"),
        )
        for i, item in enumerate(items)
    ]


def _extract_chapter_dirs(tree: list[dict]) -> list[UnitDraft]:
    """
    Detect top-level sub-directories whose parent is chapters/ lessons/ etc.,
    or top-level directories that look like chapters (e.g. 01-intro, chapter-1).
    """
    chapter_root_re = re.compile(r"^(chapter|lesson|module|part|section|week)", re.I)
    numbered_re = re.compile(r"^\d+[-_]", re.I)

    # Collect tree blobs/trees at depth 1 (no slash in path except leading segment)
    top_level_dirs: dict[str, list[str]] = {}
    for node in tree:
        path: str = node.get("path", "")
        node_type: str = node.get("type", "")
        if node_type != "tree":
            continue
        parts = path.split("/")
        if len(parts) == 1:
            top_level_dirs[path] = []
        elif len(parts) == 2:
            top_level_dirs.setdefault(parts[0], []).append(parts[1])

    candidates: list[str] = []
    for dirname in top_level_dirs:
        if chapter_root_re.match(dirname) or numbered_re.match(dirname):
            candidates.append(dirname)

    if not candidates:
        return []

    candidates.sort()
    return [
        UnitDraft(title=name, order_index=i, estimated_minutes=None)
        for i, name in enumerate(candidates)
    ]


async def _llm_fallback(owner: str, repo: str) -> list[UnitDraft]:
    """LLM fallback: estimate units purely from repo name/description."""
    from langchain_google_genai import ChatGoogleGenerativeAI

    llm = ChatGoogleGenerativeAI(
        model=GEMINI_MODEL,
        google_api_key=GEMINI_API_KEY,
        temperature=0,
    )
    prompt = (
        f"The GitHub repository '{owner}/{repo}' is a learning resource. "
        "Based only on the name, generate a reasonable ordered list of learning units. "
        "Return a JSON array of objects with keys 'title' (string) and 'estimated_minutes' (integer or null). "
        "Respond ONLY with a JSON array."
    )
    response = await llm.ainvoke(prompt)
    raw = response.content.strip()
    raw = re.sub(r"^```[a-z]*\n?", "", raw)
    raw = re.sub(r"\n?```$", "", raw)
    items: list[dict] = json.loads(raw)
    return [
        UnitDraft(
            title=item.get("title", f"Unit {i+1}"),
            order_index=i,
            estimated_minutes=item.get("estimated_minutes"),
        )
        for i, item in enumerate(items)
    ]


class GitHubHandler:
    """Handle GitHub repository URLs."""

    def __init__(self, url: str) -> None:
        self.url = url
        self.owner, self.repo = _parse_owner_repo(url)

    async def fetch(self) -> ResourceStructure:
        async with httpx.AsyncClient() as client:
            readme = await _fetch_readme(client, self.owner, self.repo)
            tree = await _fetch_tree(client, self.owner, self.repo)

        units: list[UnitDraft] = []

        # Priority 1: README has ToC → LLM parse
        if readme and _has_toc(readme):
            try:
                units = await _llm_parse_readme(readme, self.repo)
            except Exception:
                units = []

        # Priority 2: chapter/lesson dirs in tree
        if not units and tree:
            units = _extract_chapter_dirs(tree)

        # Priority 3: LLM fallback
        if not units:
            try:
                units = await _llm_fallback(self.owner, self.repo)
            except Exception:
                units = [UnitDraft(title=self.repo, order_index=0, estimated_minutes=None)]

        return ResourceStructure(
            title=f"{self.owner}/{self.repo}",
            type="github_repo",
            tracking_mode="sequential",
            url=self.url,
            units=units,
            total_estimated_hours=0.0,
        )
