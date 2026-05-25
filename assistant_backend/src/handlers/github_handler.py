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
from .models import CanonicalRepoRole, GitHubPreview, ResourceStructure, UnitDraft


def _parse_owner_repo(url: str) -> tuple[str, str]:
    """Extract (owner, repo) from a github.com URL."""
    path = urlparse(url).path.strip("/")
    parts = path.split("/")
    if len(parts) < 2:
        raise ValueError(f"Cannot parse owner/repo from URL: {url}")
    return parts[0], parts[1]


async def _fetch_readme(client: httpx.AsyncClient, owner: str, repo: str) -> str:
    """Return decoded README text, or empty string on failure."""
    readme, _succeeded = await _fetch_readme_with_status(client, owner, repo)
    return readme


async def _fetch_readme_with_status(
    client: httpx.AsyncClient, owner: str, repo: str
) -> tuple[str, bool]:
    """Return decoded README text and whether the README request succeeded."""
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
                return base64.b64decode(content).decode("utf-8", errors="replace"), True
    except Exception:
        pass
    return "", False


async def _fetch_tree(client: httpx.AsyncClient, owner: str, repo: str) -> list[dict]:
    """Return list of tree nodes from the default branch."""
    tree, _succeeded = await _fetch_tree_with_status(client, owner, repo)
    return tree


async def _fetch_tree_with_status(
    client: httpx.AsyncClient, owner: str, repo: str
) -> tuple[list[dict], bool]:
    """Return tree nodes and whether the tree request succeeded."""
    try:
        resp = await client.get(
            f"https://api.github.com/repos/{owner}/{repo}/git/trees/HEAD?recursive=1",
            headers={"Accept": "application/vnd.github+json"},
            timeout=20,
        )
        if resp.status_code == 200:
            return resp.json().get("tree", []), True
    except Exception:
        pass
    return [], False


async def _fetch_repo_metadata(client: httpx.AsyncClient, owner: str, repo: str) -> dict | None:
    """Return shallow repository metadata, or None on failure."""
    try:
        resp = await client.get(
            f"https://api.github.com/repos/{owner}/{repo}",
            headers={"Accept": "application/vnd.github+json"},
            timeout=15,
        )
        if resp.status_code == 200:
            return resp.json()
    except Exception:
        pass
    return None


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


def _extract_readme_outline(readme: str) -> list[str]:
    """Return a shallow README heading outline without inventing units."""
    headings: list[str] = []
    for line in readme.splitlines():
        match = re.match(r"^#{2,3}\s+(.+?)\s*$", line)
        if not match:
            continue
        heading = re.sub(r"\s+#+$", "", match.group(1)).strip()
        if heading:
            headings.append(heading)
    return headings[:12]


def _extract_top_level_dirs(tree: list[dict]) -> list[str]:
    dirs = {
        node.get("path", "").split("/", 1)[0]
        for node in tree
        if node.get("type") == "tree" and node.get("path") and "/" not in node.get("path", "")
    }
    return sorted(dirs)[:20]


def _infer_repo_role(
    user_hint: str | None,
    description: str | None,
    readme: str,
) -> CanonicalRepoRole | None:
    user_role = _infer_repo_role_from_text(user_hint)
    if user_role:
        return user_role
    return _infer_repo_role_from_text(
        " ".join(part for part in [description, readme[:2000]] if part),
    )


def _infer_repo_role_from_text(text: str | None) -> CanonicalRepoRole | None:
    text = (text or "").lower()
    if not text:
        return None
    if re.search(r"\b(clone|rebuild|re-create|recreate|implement from scratch)\b", text):
        return "clone_rebuild_target"
    if re.search(r"\b(project material|portfolio|resume|my project|existing project)\b", text):
        return "project_material"
    if re.search(r"\b(later|someday|bookmark|read later)\b", text):
        return "later_reading"
    if re.search(r"\b(reference|docs?|documentation|lookup|look up)\b", text):
        return "reference_source"
    if re.search(r"\b(learn|course|tutorial|workshop|curriculum|study)\b", text):
        return "main_learning_object"
    return None


def _mark_low_calibration_synthetic(units: list[UnitDraft]) -> list[UnitDraft]:
    for unit in units:
        unit.is_synthetic = True
        unit.calibration = "low"
    return units


def _preview_fetch_status(
    metadata: dict | None,
    readme_succeeded: bool,
    tree_succeeded: bool,
) -> str:
    if not metadata and not readme_succeeded and not tree_succeeded:
        return "unavailable"
    if metadata and readme_succeeded and tree_succeeded:
        return "available"
    return "partial"


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
                units = _mark_low_calibration_synthetic(
                    await _llm_fallback(self.owner, self.repo)
                )
            except Exception:
                units = _mark_low_calibration_synthetic(
                    [UnitDraft(title=self.repo, order_index=0, estimated_minutes=None)]
                )

        return ResourceStructure(
            title=f"{self.owner}/{self.repo}",
            type="github_repo",
            tracking_mode="sequential",
            url=self.url,
            units=units,
            total_estimated_hours=0.0,
        )

    async def preview(self, user_hint: str | None = None) -> GitHubPreview:
        async with httpx.AsyncClient() as client:
            metadata = await _fetch_repo_metadata(client, self.owner, self.repo)
            readme, readme_succeeded = await _fetch_readme_with_status(
                client, self.owner, self.repo
            )
            tree, tree_succeeded = await _fetch_tree_with_status(client, self.owner, self.repo)

        title = (metadata or {}).get("full_name") or f"{self.owner}/{self.repo}"
        description = (metadata or {}).get("description")
        topics = list((metadata or {}).get("topics") or [])
        readme_outline = _extract_readme_outline(readme) if readme else []
        coarse_dirs = _extract_top_level_dirs(tree) if tree else []
        fetch_status = _preview_fetch_status(metadata, readme_succeeded, tree_succeeded)
        calibration = "medium" if any([description, topics, readme_outline, coarse_dirs]) else "low"

        return GitHubPreview(
            title=title,
            source_type="github_repo",
            url=self.url,
            description=description,
            readme_outline=readme_outline,
            topics=topics,
            coarse_directory_signals=coarse_dirs,
            fetch_status=fetch_status,
            calibration=calibration,
            canonical_repo_role=_infer_repo_role(user_hint, description, readme),
        )
