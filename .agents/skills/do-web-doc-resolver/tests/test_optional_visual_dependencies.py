"""The core CLI uses declared dependencies without optional or obsolete stacks."""

import os
import subprocess
import sys
from pathlib import Path

import pytest

SKILL_ROOT = Path(__file__).resolve().parents[1]
SUBPROCESS_TIMEOUT_SECONDS = 30
BLOCK_OPTIONAL_IMPORTS = """
import importlib.abc
import sys

class BlockOptionalDependencies(importlib.abc.MetaPathFinder):
    def find_spec(self, fullname, path=None, target=None):
        if fullname.split('.')[0] in {
            'numpy', 'PIL', 'playwright', 'sentence_transformers', 'duckduckgo_search'
        }:
            raise ModuleNotFoundError(f'Optional dependency unavailable: {fullname}', name=fullname)

sys.meta_path.insert(0, BlockOptionalDependencies())
"""


def run_without_optional_dependencies(code, tmp_path):
    environment = {
        **os.environ,
        "PYTHONDONTWRITEBYTECODE": "1",
        "DO_WDR_SEMANTIC_CACHE": "0",
        "WEB_RESOLVER_CACHE_DIR": str(tmp_path / "cache"),
        "DO_WDR_ROUTING_MEMORY_PATH": str(tmp_path / "routing.json"),
        "MISTRAL_API_KEY": "test-placeholder",
        "OPENROUTER_API_KEY": "",
    }
    return subprocess.run(
        [sys.executable, "-c", BLOCK_OPTIONAL_IMPORTS + code],
        cwd=SKILL_ROOT,
        env=environment,
        capture_output=True,
        text=True,
        timeout=SUBPROCESS_TIMEOUT_SECONDS,
        check=False,
    )


def test_text_cli_starts_without_visual_extras(tmp_path):
    result = run_without_optional_dependencies(
        """
import runpy
sys.argv = ['do-wdr', '--help']
runpy.run_module('scripts.cli', run_name='__main__')
""",
        tmp_path,
    )
    assert result.returncode == 0, result.stderr
    assert "Web Doc Resolver" in result.stdout
    assert "--profile" in result.stdout


@pytest.mark.parametrize("asynchronous", [False, True])
def test_declared_search_dependency_works_without_legacy_package(asynchronous, tmp_path):
    call = (
        "asyncio.run(resolve_with_duckduckgo_async('fixture query'))"
        if asynchronous
        else "resolve_with_duckduckgo('fixture query')"
    )
    result = run_without_optional_dependencies(
        f"""
import asyncio
from unittest.mock import patch
from scripts.providers.duckduckgo import resolve_with_duckduckgo, resolve_with_duckduckgo_async
with patch('ddgs.DDGS') as factory:
    factory.return_value.__enter__.return_value.text.return_value = [
        {{'title': 'Fixture', 'body': 'fixture search content'}}
    ]
    result = {call}
if result is None or 'fixture search content' not in result.content:
    raise AssertionError('Search must use the declared ddgs dependency')
""",
        tmp_path,
    )
    assert result.returncode == 0, result.stderr


@pytest.mark.parametrize("asynchronous", [False, True])
def test_unavailable_visual_provider_falls_back(asynchronous, tmp_path):
    call = (
        "asyncio.run(resolve_with_visual_clip_async('https://example.com'))"
        if asynchronous
        else "resolve_with_visual_clip('https://example.com')"
    )
    result = run_without_optional_dependencies(
        f"""
import asyncio
from scripts.providers.visual_clip import resolve_with_visual_clip, resolve_with_visual_clip_async
result = {call}
if result is not None:
    raise AssertionError('An unavailable optional provider must return no result')
""",
        tmp_path,
    )
    assert result.returncode == 0, result.stderr
