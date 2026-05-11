import json
import logging
import os
import sys

import requests

# Add current directory to path
sys.path.insert(0, os.path.abspath(os.curdir))

from scripts.providers_impl import (
    resolve_with_duckduckgo,
    resolve_with_exa_mcp,
    resolve_with_firecrawl,
    resolve_with_jina,
    resolve_with_tavily,
)
from scripts.utils import get_session

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("diagnose")

TEST_URL = "https://docs.python.org/3/"
TEST_QUERY = "Latest Python 3.13 features"


def diagnose_jina():
    print("\n--- Diagnosing Jina ---")
    url = f"https://r.jina.ai/{TEST_URL}"
    headers = {"Accept": "text/markdown"}
    try:
        session = get_session()
        response = session.get(url, headers=headers, timeout=10)
        print(f"Status Code: {response.status_code}")
        print(f"Headers: {json.dumps(dict(response.headers), indent=2)}")
        print(f"Content length: {len(response.text)}")
        print(f"Content snippet: {response.text[:200]}...")

        result = resolve_with_jina(TEST_URL)
        print(f"Resolved Result source: {result.source if result else 'None'}")
    except Exception as e:
        print(f"Jina error: {e}")


def diagnose_firecrawl():
    print("\n--- Diagnosing Firecrawl ---")
    api_key = os.getenv("FIRECRAWL_API_KEY")
    if not api_key:
        print("FIRECRAWL_API_KEY not set")
        return

    # Direct API check for headers/schema
    try:
        response = requests.post(
            "https://api.firecrawl.dev/v1/scrape",
            headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
            json={"url": TEST_URL, "formats": ["markdown"]},
            timeout=20,
        )
        print(f"Status Code: {response.status_code}")
        print(f"Headers: {json.dumps(dict(response.headers), indent=2)}")
        data = response.json()
        print(f"Response keys: {data.keys()}")
        if "data" in data:
            print(f"Data keys: {data['data'].keys()}")

        from firecrawl import Firecrawl

        app = Firecrawl(api_key=api_key)
        res = app.scrape(TEST_URL, formats=["markdown"])
        print(f"Firecrawl app.scrape response type: {type(res)}")
        if isinstance(res, dict):
            print(f"Firecrawl app.scrape response keys: {res.keys()}")
        else:
            print(f"Firecrawl app.scrape response attrs: {dir(res)}")

        result = resolve_with_firecrawl(TEST_URL)
        print(f"Resolved Result source: {result.source if result else 'None'}")
    except Exception as e:
        print(f"Firecrawl error: {e}")


def diagnose_tavily():
    print("\n--- Diagnosing Tavily ---")
    api_key = os.getenv("TAVILY_API_KEY")
    if not api_key:
        print("TAVILY_API_KEY not set")
        return

    try:
        response = requests.post(
            "https://api.tavily.com/search",
            json={"api_key": api_key, "query": TEST_QUERY, "max_results": 2},
            timeout=10,
        )
        print(f"Status Code: {response.status_code}")
        print(f"Headers: {json.dumps(dict(response.headers), indent=2)}")
        data = response.json()
        print(f"Response keys: {data.keys()}")
        if "results" in data:
            print(f"Number of results: {len(data['results'])}")
            if data["results"]:
                print(f"Result keys: {data['results'][0].keys()}")

        result = resolve_with_tavily(TEST_QUERY)
        print(f"Resolved Result source: {result.source if result else 'None'}")
    except Exception as e:
        print(f"Tavily error: {e}")


def diagnose_exa_mcp():
    print("\n--- Diagnosing Exa MCP ---")
    try:
        result = resolve_with_exa_mcp(TEST_QUERY)
        print(f"Resolved Result source: {result.source if result else 'None'}")
        if result:
            print(f"Content length: {len(result.content)}")
    except Exception as e:
        print(f"Exa MCP error: {e}")


def diagnose_duckduckgo():
    print("\n--- Diagnosing DuckDuckGo ---")
    try:
        result = resolve_with_duckduckgo(TEST_QUERY)
        print(f"Resolved Result source: {result.source if result else 'None'}")
        if result:
            print(f"Content length: {len(result.content)}")
    except Exception as e:
        print(f"DuckDuckGo error: {e}")


if __name__ == "__main__":
    diagnose_jina()
    diagnose_firecrawl()
    diagnose_tavily()
    diagnose_exa_mcp()
    diagnose_duckduckgo()
