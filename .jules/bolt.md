## 2026-05-03 - Added Dependency Check for discover-commands.sh
**Learning:** Found that `scripts/discover-commands.sh` silently fails and produces empty JSON outputs when `jq` is not installed, which breaks downstream pipeline steps.
**Action:** Added a fast-failing dependency check for `jq` before executing the `awk` pipeline, ensuring errors are clear and explicitly output to `stderr`.
