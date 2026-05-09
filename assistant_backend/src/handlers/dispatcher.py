"""
URL dispatcher: identifies URL type and returns the corresponding Handler class.
"""
from __future__ import annotations

import re
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .github_handler import GitHubHandler
    from .bilibili_handler import BilibiliHandler
    from .pdf_handler import PDFHandler
    from .web_handler import WebHandler


def dispatch(url: str) -> type:
    """
    Analyse *url* and return the appropriate (un-instantiated) Handler class.

    Priority rules
    --------------
    1. github.com/*           → GitHubHandler
    2. bilibili.com/video/BV* → BilibiliHandler
    3. ends with .pdf         → PDFHandler
    4. everything else        → WebHandler
    """
    url_lower = url.strip().lower()

    if re.search(r"github\.com/", url_lower):
        from .github_handler import GitHubHandler
        return GitHubHandler

    if re.search(r"bilibili\.com/video/bv", url_lower):
        from .bilibili_handler import BilibiliHandler
        return BilibiliHandler

    if url_lower.endswith(".pdf") or re.search(r"\.pdf(\?.*)?$", url_lower):
        from .pdf_handler import PDFHandler
        return PDFHandler

    from .web_handler import WebHandler
    return WebHandler
