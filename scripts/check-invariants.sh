#!/usr/bin/env bash
# ============================================================================
# check-invariants.sh — Automated Executable-Invariants Registry Validator
# ============================================================================
#
# Verifies that plans/invariants.json:
# 1. Is valid JSON and adheres to the invariants registry schema.
# 2. Contains required non-empty fields: invariant, rationale, sensor, category.
# 3. Uses controlled categories (security, architecture, workflow, quality).
# 4. Contains no duplicate invariant entries.
# 5. Resolves every file-based sensor to an existing, tracked file within REPO_ROOT
#    without path traversal.
#
# Usage:
#   ./scripts/check-invariants.sh [path/to/invariants.json]
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY_FILE="${1:-"$REPO_ROOT/plans/invariants.json"}"

if [[ ! -f "$REGISTRY_FILE" ]]; then
  printf "  ✗ Invariants registry not found: %s\n" "$REGISTRY_FILE" >&2
  exit 1
fi

python3 - "$REPO_ROOT" "$REGISTRY_FILE" <<'EOF'
import json
import os
import sys

ALLOWED_CATEGORIES = {"security", "architecture", "workflow", "quality"}

def main():
    repo_root = os.path.abspath(sys.argv[1])
    registry_file = sys.argv[2]

    try:
        with open(registry_file, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"  ✗ Invalid JSON in {registry_file}: {e}", file=sys.stderr)
        sys.exit(1)

    if isinstance(data, dict):
        if "invariants" not in data or not isinstance(data["invariants"], list):
            print(f"  ✗ Invariants registry root object must contain an 'invariants' array.", file=sys.stderr)
            sys.exit(1)
        entries = data["invariants"]
    elif isinstance(data, list):
        entries = data
    else:
        print(f"  ✗ Invariants registry root must be a JSON object with 'invariants' array or a list.", file=sys.stderr)
        sys.exit(1)

    errors = []
    seen_invariants = set()

    for idx, entry in enumerate(entries):
        if not isinstance(entry, dict):
            errors.append(f"Entry #{idx+1} is not a JSON object.")
            continue

        inv_text = entry.get("invariant")
        rationale = entry.get("rationale")
        sensor = entry.get("sensor")
        category = entry.get("category")

        # Required fields check
        if not inv_text or not isinstance(inv_text, str) or not inv_text.strip():
            errors.append(f"Entry #{idx+1} missing or empty 'invariant' field.")
            inv_text = f"Entry #{idx+1}"
        else:
            inv_text = inv_text.strip()

        if not rationale or not isinstance(rationale, str) or not rationale.strip():
            errors.append(f"[{inv_text}] missing or empty 'rationale' field.")

        if not category or not isinstance(category, str) or not category.strip():
            errors.append(f"[{inv_text}] missing or empty 'category' field.")
        elif category.strip().lower() not in ALLOWED_CATEGORIES:
            errors.append(f"[{inv_text}] invalid category '{category}'. Must be one of: {', '.join(sorted(ALLOWED_CATEGORIES))}.")

        # Duplicate detection
        norm_inv = inv_text.lower()
        if norm_inv in seen_invariants:
            errors.append(f"Duplicate invariant text detected: '{inv_text}'.")
        else:
            seen_invariants.add(norm_inv)

        # Sensor resolution check
        if not sensor:
            errors.append(f"[{inv_text}] missing or empty 'sensor' field.")
        elif isinstance(sensor, str):
            sensor_path_str = sensor.strip()
            if not sensor_path_str:
                errors.append(f"[{inv_text}] sensor path is empty.")
            elif os.path.isabs(sensor_path_str) or ".." in sensor_path_str.split(os.sep):
                errors.append(f"[{inv_text}] sensor path '{sensor_path_str}' contains path traversal or absolute path.")
            else:
                full_sensor_path = os.path.normpath(os.path.join(repo_root, sensor_path_str))
                if not full_sensor_path.startswith(repo_root + os.sep) and full_sensor_path != repo_root:
                    errors.append(f"[{inv_text}] sensor path '{sensor_path_str}' resolves outside repository root.")
                elif not os.path.isfile(full_sensor_path):
                    errors.append(f"[{inv_text}] sensor file does not exist: '{sensor_path_str}'.")
        elif isinstance(sensor, dict):
            kind = sensor.get("kind")
            if not kind or not isinstance(kind, str) or not kind.strip():
                errors.append(f"[{inv_text}] sensor object missing non-empty 'kind' field.")
            else:
                kind = kind.strip().lower()
                if kind in {"file", "script", "workflow"}:
                    spath = sensor.get("path")
                    if not spath or not isinstance(spath, str) or not spath.strip():
                        errors.append(f"[{inv_text}] file-based sensor object missing non-empty 'path' field.")
                    else:
                        spath = spath.strip()
                        if os.path.isabs(spath) or ".." in spath.split(os.sep):
                            errors.append(f"[{inv_text}] sensor path '{spath}' contains path traversal or absolute path.")
                        else:
                            full_spath = os.path.normpath(os.path.join(repo_root, spath))
                            if not full_spath.startswith(repo_root + os.sep) and full_spath != repo_root:
                                errors.append(f"[{inv_text}] sensor path '{spath}' resolves outside repository root.")
                            elif not os.path.isfile(full_spath):
                                errors.append(f"[{inv_text}] sensor file does not exist: '{spath}'.")
                elif kind == "command":
                    cmd = sensor.get("cmd")
                    if not cmd or not isinstance(cmd, str) or not cmd.strip():
                        errors.append(f"[{inv_text}] command sensor object missing non-empty 'cmd' field.")
                else:
                    errors.append(f"[{inv_text}] unsupported sensor kind '{kind}'.")
        else:
            errors.append(f"[{inv_text}] sensor field must be a relative file path string or sensor object.")

    if errors:
        for err in errors:
            print(f"  ✗ {err}", file=sys.stderr)
        sys.exit(1)

    print(f"  ✓ Validated {len(entries)} invariant(s) in {os.path.relpath(registry_file, repo_root)}.")
    sys.exit(0)

if __name__ == "__main__":
    main()
EOF
