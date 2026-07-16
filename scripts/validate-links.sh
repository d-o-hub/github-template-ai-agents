#!/usr/bin/env bash
# Validates reference links in SKILL.md, top-level docs, agents-docs, and llms*.txt files.
# Checks that all markdown links point to existing files.
# Exit 0 if all links valid, non-zero if broken links or format errors found.
# shellcheck disable=SC2094
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.agents/skills"
AGENTS_DOCS_DIR="$REPO_ROOT/agents-docs"

RESOLVED_ROOT=""
if command -v realpath &> /dev/null; then
    RESOLVED_ROOT=$(realpath -m "$REPO_ROOT")
fi

BROKEN_COUNT=0
FORMAT_ERRORS=0
FILES_CHECKED=0
LINKS_CHECKED=0

# shellcheck source=scripts/lib/link-validation.sh
source "$REPO_ROOT/scripts/lib/link-validation.sh"

# Main entry point: discover and process all skill files
# Uses a batched awk process to filter relevant lines across all SKILL.md files.
# This eliminates per-file process forks, providing significant speedup.

if [[ ! -d "$SKILLS_DIR" ]]; then
    printf "%b\n" "${YELLOW}⚠${NC} Skills directory not found: $SKILLS_DIR (continuing with docs)."
fi

# Collect all SKILL.md files, skipping backup folders (underscore prefix)
# Performance optimization: use native bash globbing instead of find/sort subshells
SKILL_FILES=()
shopt -s nullglob
for skill_dir in "$SKILLS_DIR"/*/; do
    skill_file="${skill_dir}SKILL.md"
    skill_name="${skill_dir%/}"
    skill_name="${skill_name##*/}"
    [[ "$skill_name" == _* ]] && continue
    if [[ -f "$skill_file" ]]; then
        SKILL_FILES+=("$skill_file")
    fi
done
shopt -u nullglob

if [[ ${#SKILL_FILES[@]} -eq 0 ]]; then
    printf "%b\n" "${YELLOW}⚠${NC} No SKILL.md files found (continuing with docs)."
fi

current_skill_file=""
file_broken=0
file_format_errors=0

# Process all files with a single awk call.
# Format: FILENAME:LINE_NUM:IN_REF:CONTENT

lines_array=()
if [[ ${#SKILL_FILES[@]} -gt 0 ]]; then

old_opts="$-"
old_ifs="$IFS"
set -f
IFS=$'\n'
lines_array=($(awk -- '
    BEGIN { in_ref = 0 }
    FNR == 1 { in_ref = 0; print FILENAME ":0:0:__START__" }
    /^##[[:space:]]+[Rr]eferences/ { in_ref = 1; print FILENAME ":" FNR ":" in_ref ":" $0; next }
    /^##[[:space:]]+/ { in_ref = 0; print FILENAME ":" FNR ":" in_ref ":" $0; next }
    /\[[^]]+\]\([^)]+\)/ || /`(references?\/|docs\/)[^`]+`/ || /@references?/ || (in_ref && /^- /) {
        print FILENAME ":" FNR ":" in_ref ":" $0
    }
' "${SKILL_FILES[@]}"))
[[ "$old_opts" != *f* ]] && set +f
IFS="$old_ifs"

for array_line in "${lines_array[@]}"; do
    skill_file="${array_line%%:*}"
    rest="${array_line#*:}"
    line_num="${rest%%:*}"
    rest="${rest#*:}"
    in_references="${rest%%:*}"
    line="${rest#*:}"

    # Handle file transition and reporting
    if [[ "$skill_file" != "$current_skill_file" ]]; then
        if [[ -n "$current_skill_file" ]]; then
            if [[ $file_broken -eq 0 && $file_format_errors -eq 0 ]]; then
                skill_dir="${current_skill_file%/*}"
                printf "  ${GREEN}✓${NC} %s: All links valid\n" "${skill_dir##*/}"
            fi
        fi
        current_skill_file="$skill_file"
        file_broken=0
        file_format_errors=0
        FILES_CHECKED=$((FILES_CHECKED + 1))
        skill_dir="${skill_file%/*}"
        # Skip processing for the start-of-file marker
        [[ "$line_num" == "0" ]] && continue
    fi

    # Track if we're in the References section
    if is_references_header "$line"; then
        continue
    elif is_section_header "$line"; then
        continue
    fi

    # Check reference format (only in References section)
    if [[ "$in_references" -eq 1 ]]; then
        if ! check_reference_format "$line" "$line_num" "$skill_file" "$skill_dir"; then
            FORMAT_ERRORS=$((FORMAT_ERRORS + 1))
            file_format_errors=1
        fi
    fi

    # Find all markdown links in this line
    temp_line="$line"
    while [[ "$temp_line" =~ $LINK_REGEX ]]; do
        full_match="${BASH_REMATCH[0]}"
        link_path="${BASH_REMATCH[2]}"
        temp_line="${temp_line#*"$full_match"}"

        if [[ "$line" =~ example[[:space:]]*[:\(] ]] || [[ "$link_path" =~ \.(svg|png|jpg|jpeg|gif)$ ]]; then
            continue
        fi

        LINKS_CHECKED=$((LINKS_CHECKED + 1))
        if ! check_link "$skill_dir" "$link_path" "$skill_file" "$line_num"; then
            BROKEN_COUNT=$((BROKEN_COUNT + 1))
            file_broken=1
        fi
    done

    # Check for backtick-wrapped paths that look like references
    if [[ "$line" =~ \`(references?/[a-zA-Z0-9_-]+\.md)\` ]]; then
        ref_path="${BASH_REMATCH[1]}"
        LINKS_CHECKED=$((LINKS_CHECKED + 1))
        if ! check_link "$skill_dir" "$ref_path" "$skill_file" "$line_num"; then
            BROKEN_COUNT=$((BROKEN_COUNT + 1))
            file_broken=1
        fi
    fi

    # Check for backtick-wrapped paths in docs/
    if [[ "$line" =~ \`(docs/[a-zA-Z0-9_/-]+\.md)\` ]]; then
        docs_path="${BASH_REMATCH[1]}"
        LINKS_CHECKED=$((LINKS_CHECKED + 1))
        if ! check_link "$skill_dir" "$docs_path" "$skill_file" "$line_num"; then
            BROKEN_COUNT=$((BROKEN_COUNT + 1))
            file_broken=1
        fi
    fi

    # Check for deprecated @references
    if [[ "$line" =~ @(references?/[a-zA-Z0-9_-]+\.md) ]]; then
        at_ref="${BASH_REMATCH[1]}"
        printf "  ${RED}✗${NC} Broken @reference at line %s: @%s\n" "$line_num" "$at_ref" >&2
        printf "     @ prefix is deprecated. Use: \`reference/filename.md\` or \`references/filename.md\`\n" >&2
        printf "     in: %s\n" "$skill_file" >&2
        BROKEN_COUNT=$((BROKEN_COUNT + 1))
        file_broken=1
    fi
done

    # Final report for the last SKILL.md file
    if [[ -n "$current_skill_file" ]]; then
        if [[ $file_broken -eq 0 && $file_format_errors -eq 0 ]]; then
            skill_dir="${current_skill_file%/*}"
            printf "  ${GREEN}✓${NC} %s: All links valid\n" "${skill_dir##*/}"
        fi
    fi

fi # end of SKILL_FILES processing

# ============================================================================
# Phase 2: Validate links in top-level docs, agents-docs, and llms*.txt
# These files use standard markdown links but don't have SKILL.md-specific
# reference format rules. We only check that link targets exist.
# ============================================================================

# Collect top-level markdown files
TOPLEVEL_FILES=()
for toplevel_name in README.md QUICKSTART.md AGENTS.md; do
    toplevel_path="$REPO_ROOT/$toplevel_name"
    if [[ -f "$toplevel_path" ]]; then
        TOPLEVEL_FILES+=("$toplevel_path")
    fi
done

# Collect llms*.txt files
LLMS_FILES=()
shopt -s nullglob
for llms_path in "$REPO_ROOT"/llms*.txt; do
    if [[ -f "$llms_path" ]]; then
        LLMS_FILES+=("$llms_path")
    fi
done
shopt -u nullglob

# Collect agents-docs/*.md files (excluding references/ subdirectory)
AGENTS_DOCS_FILES=()
shopt -s nullglob
for agents_doc in "$AGENTS_DOCS_DIR"/*.md; do
    if [[ -f "$agents_doc" ]]; then
        AGENTS_DOCS_FILES+=("$agents_doc")
    fi
done
shopt -u nullglob

# Combine all non-skill docs into one array
ALL_DOCS_FILES=("${TOPLEVEL_FILES[@]}" "${LLMS_FILES[@]}" "${AGENTS_DOCS_FILES[@]}")

docs_lines_array=()
if [[ ${#ALL_DOCS_FILES[@]} -eq 0 ]]; then
    printf "%b\n" "${YELLOW}⚠${NC} No top-level/docs files found for link validation."
fi

if [[ ${#ALL_DOCS_FILES[@]} -gt 0 ]]; then
    current_file=""
    file_broken=0

    old_opts="$-"
    old_ifs="$IFS"
    set -f
    IFS=$'\n'
    docs_lines_array=($(awk '
        FNR == 1 { print FILENAME ":0:__START__" }
        /\[[^]]+\]\([^)]+\)/ { print FILENAME ":" FNR ":" $0 }
    ' "${ALL_DOCS_FILES[@]}"))
    [[ "$old_opts" != *f* ]] && set +f
    IFS="$old_ifs"

    for array_line in "${docs_lines_array[@]}"; do
        doc_file="${array_line%%:*}"
        rest="${array_line#*:}"
        line_num="${rest%%:*}"
        line="${rest#*:}"

        # Handle file transition and reporting
        if [[ "$doc_file" != "$current_file" ]]; then
            if [[ -n "$current_file" ]]; then
                if [[ $file_broken -eq 0 ]]; then
                    display_path="${current_file#"$REPO_ROOT"/}"
                    printf "  ${GREEN}✓${NC} %s: All links valid\n" "$display_path"
                fi
            fi
            current_file="$doc_file"
            file_broken=0
            FILES_CHECKED=$((FILES_CHECKED + 1))
            # Skip processing for the start-of-file marker
            [[ "$line_num" == "0" ]] && continue
        fi

        # Compute the directory of the source file for relative link resolution
        doc_dir="${doc_file%/*}"

        # Find all markdown links in this line
        temp_line="$line"
        while [[ "$temp_line" =~ $LINK_REGEX ]]; do
            full_match="${BASH_REMATCH[0]}"
            link_path="${BASH_REMATCH[2]}"
            temp_line="${temp_line#*"$full_match"}"

            # Skip image links
            if [[ "$line" =~ example[[:space:]]*[:\(] ]] || [[ "$link_path" =~ \.(svg|png|jpg|jpeg|gif)$ ]]; then
                continue
            fi

            LINKS_CHECKED=$((LINKS_CHECKED + 1))
            if ! check_link "$doc_dir" "$link_path" "$doc_file" "$line_num"; then
                BROKEN_COUNT=$((BROKEN_COUNT + 1))
                file_broken=1
            fi
        done
    done

    # Final report for the last docs file
    if [[ -n "$current_file" ]]; then
        if [[ $file_broken -eq 0 ]]; then
            display_path="${current_file#"$REPO_ROOT"/}"
            printf "  ${GREEN}✓${NC} %s: All links valid\n" "$display_path"
        fi
    fi
fi

printf "\n"
printf "─────────────────────────────────────────────────────────────────\n"

TOTAL_ERRORS=$((BROKEN_COUNT + FORMAT_ERRORS))

if [[ $TOTAL_ERRORS -gt 0 ]]; then
    printf "│ ${RED}✗ Link Validation FAILED${NC}                                      │\n" >&2
    printf "─────────────────────────────────────────────────────────────────\n" >&2
    printf "\n" >&2
    printf "  Files checked: %s\n" "$FILES_CHECKED" >&2
    printf "  Links checked: %s\n" "$LINKS_CHECKED" >&2
    printf "  ${RED}Broken links: %s${NC}\n" "$BROKEN_COUNT" >&2
    printf "  ${RED}Format errors: %s${NC}\n" "$FORMAT_ERRORS" >&2
    echo "" >&2
    echo "  Fix broken links by:" >&2
    echo "    1. Creating missing referenced files" >&2
    echo "    2. Updating link paths in source files" >&2
    echo "    3. Removing obsolete links" >&2
    echo "" >&2
    echo "  Reference format in SKILL.md should be:" >&2
    echo "    - \`references?/filename.md\` - Description" >&2
    exit 1
else
    printf "│ ${GREEN}✓ All reference links valid${NC}                                   │\n"
    printf "─────────────────────────────────────────────────────────────────\n"
    printf "\n"
    printf "  Files checked: %s\n" "$FILES_CHECKED"
    printf "  Links checked: %s\n" "$LINKS_CHECKED"
    printf "  Broken links: 0\n"
    exit 0
fi
