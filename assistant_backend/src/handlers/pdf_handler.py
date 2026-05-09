"""
PDF Handler — extracts chapter headings from a PDF file or URL.

Chapter detection heuristics
-----------------------------
1. Lines matching "Chapter N" / "CHAPTER N"
2. All-uppercase lines that are short enough to be headings (≤ 80 chars)
"""
from __future__ import annotations

import io
import re
import tempfile
from pathlib import Path
from urllib.parse import urlparse

import httpx
from pypdf import PdfReader

from .models import ResourceStructure, UnitDraft


def _is_chapter_heading(line: str) -> bool:
    line = line.strip()
    if not line:
        return False
    # "Chapter N" / "CHAPTER N" with optional title
    if re.match(r"^(chapter|CHAPTER)\s+\d+", line):
        return True
    # All-caps short line (title case headings stripped from TOC)
    if line.isupper() and 3 <= len(line) <= 80:
        return True
    return False


def _extract_chapters_from_text(text: str) -> list[str]:
    chapters: list[str] = []
    for line in text.splitlines():
        if _is_chapter_heading(line):
            chapters.append(line.strip())
    return chapters


async def _download_pdf(url: str) -> bytes:
    async with httpx.AsyncClient(follow_redirects=True) as client:
        resp = await client.get(url, timeout=30)
        resp.raise_for_status()
        return resp.content


def _read_pdf_text(pdf_bytes: bytes) -> str:
    reader = PdfReader(io.BytesIO(pdf_bytes))
    parts: list[str] = []
    for page in reader.pages:
        try:
            parts.append(page.extract_text() or "")
        except Exception:
            pass
    return "\n".join(parts)


class PDFHandler:
    """Handle PDF files accessed via URL or local file path."""

    def __init__(self, url: str) -> None:
        self.url = url

    def _is_local(self) -> bool:
        parsed = urlparse(self.url)
        return parsed.scheme in ("", "file") or Path(self.url).exists()

    async def fetch(self) -> ResourceStructure:
        if self._is_local():
            path = urlparse(self.url).path or self.url
            pdf_bytes = Path(path).read_bytes()
        else:
            pdf_bytes = await _download_pdf(self.url)

        text = _read_pdf_text(pdf_bytes)
        chapters = _extract_chapters_from_text(text)

        if not chapters:
            # Fallback: treat the whole document as a single unit
            filename = Path(urlparse(self.url).path).stem or "Document"
            units = [UnitDraft(title=filename, order_index=0, estimated_minutes=None)]
            title = filename
        else:
            units = [
                UnitDraft(title=ch, order_index=i, estimated_minutes=None)
                for i, ch in enumerate(chapters)
            ]
            # Use the first heading as the document title, or derive from URL
            title = Path(urlparse(self.url).path).stem or chapters[0]

        return ResourceStructure(
            title=title,
            type="pdf",
            tracking_mode="sequential",
            url=self.url,
            units=units,
            total_estimated_hours=0.0,
        )
