#!/usr/bin/env python3
"""Deterministic stub adapter for behavioral-eval contract tests.

Reads one `behavioral-eval/v1` task JSON from stdin and prints one result
document. It never calls a model: it exists so the runner's pairing, scoring,
negative-case, and malformed-output handling can be tested offline.

Behavior is selected with STUB_MODE:
    ok             every assertion passes; activation observed
    fail           one assertion is graded fail
    degraded       second assertion fails only in the with_skill configuration
    malformed      prints text that is not JSON
    crash          exits non-zero with no stdout
    no_activation  activation is unobserved (null)
    negative_trigger  the skill is reported loaded for every case
    blocked        the adapter reports status blocked with a reason
"""

from __future__ import annotations

import json
import os
import sys

SCHEMA_VERSION = "behavioral-eval/v1"


def main() -> int:
    mode = os.environ.get("STUB_MODE", "ok")
    if mode == "malformed":
        sys.stdout.write("this is not json\n")
        return 0
    if mode == "crash":
        sys.stderr.write("stub adapter crashed deliberately\n")
        return 7
    task = json.load(sys.stdin)
    case = task["case"]
    configuration = task["configuration"]
    skill_name = task["skill_name"]
    base = {
        "schema_version": SCHEMA_VERSION,
        "skill_name": skill_name,
        "case_id": case["id"],
        "configuration": configuration,
        "provider": {"name": "stub", "model": "stub-model", "observed": True},
    }
    if mode == "blocked":
        return _emit({**base, "status": "blocked", "reason": "stub reported a blocked session"})
    results = []
    for index, assertion in enumerate(case["assertions"], start=1):
        result = "pass"
        if mode == "fail" and index == 1:
            result = "fail"
        if mode == "degraded" and configuration == "with_skill" and index == 2:
            result = "fail"
        results.append({
            "text": assertion,
            "result": result,
            "evidence": f"stub evidence for case {case['id']} assertion {index} ({configuration})",
        })
    loaded = True
    if mode == "no_activation":
        loaded = None
    if case["bucket"] == "negative":
        loaded = mode == "negative_trigger"
    payload = {
        **base,
        "status": "graded",
        "assertion_results": results,
        "activation": {
            "skill_loaded": loaded,
            "selected_skill": skill_name if loaded else None,
            "evidence": f"stub activation evidence ({mode})",
        },
        "duration_ms": 12.5,
        "usage": {
            "total_tokens": 100 + case["id"] if configuration == "with_skill" else 80 + case["id"],
            "cost_usd": 0.001 * case["id"],
            "source": "stub adapter (deterministic, not a real model)",
        },
    }
    return _emit(payload)


def _emit(payload: dict) -> int:
    sys.stdout.write(json.dumps(payload))
    return 0


if __name__ == "__main__":
    sys.exit(main())
