## 2026-05-06 - Auto patch version bump script
**Learning:** Adding a shell script that acts as an orchestration tool for version bumping, reading from `VERSION`, updating `CHANGELOG-TEMPLATE.md` automatically via `awk`, and then delegating to `propagate-version.sh` simplifies the tedious release process and avoids manual version string edits across files.
