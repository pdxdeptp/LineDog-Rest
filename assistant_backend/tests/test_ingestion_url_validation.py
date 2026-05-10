"""URL validation for learning material ingestion."""

import pytest

from src.agents.ingestion_agent import validate_learning_material_url


def test_validate_accepts_https_with_host():
    validate_learning_material_url("https://example.com/course")


def test_validate_accepts_http_localhost():
    validate_learning_material_url("http://127.0.0.1:8080/readme")


def test_validate_rejects_relative_or_schemeless():
    with pytest.raises(ValueError, match="http"):
        validate_learning_material_url("example.com/foo")


def test_validate_rejects_non_http_scheme():
    with pytest.raises(ValueError, match="http"):
        validate_learning_material_url("ftp://example.com/a")


def test_validate_rejects_whitespace_only():
    with pytest.raises(ValueError):
        validate_learning_material_url("   ")
