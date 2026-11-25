#!/usr/bin/env bash
# Validates markdown link targets in every skill document, the top-level docs, agents-docs,
# and llms*.txt files.
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

# Collect every markdown document inside a skill, not just SKILL.md.
#
# Scope used to be one SKILL.md per skill, so the ~170 companion files (references/, sdks/,
# agents/, the skill README/AGENTS files) were never link-checked while the gate still reported
# "All reference links valid". Widening the file list is only honest if resolution follows the
# rule a renderer uses: a relative link resolves against the *containing file's* directory, not
# the skill root. Those coincide for SKILL.md, which sits in the skill root, so SKILL.md verdicts
# are unchanged; for a file in references/ they do not coincide, and `references/commands.md`
# written there really does point at references/references/commands.md.
#
# Excluded: backup folders (underscore prefix), caches, and eval fixtures. `evals/` holds test
# *inputs* — `skill-creator/evals/bad-references-input.md` is meant to be invalid and its paths
# describe a sandbox, so link integrity there is not a property anyone wants preserved.
SKILL_FILES=()
while IFS= read -r skill_md_file; do
    SKILL_FILES+=("$skill_md_file")
done < <(
    find "$SKILLS_DIR" -type f -name '*.md' \
        -not -path '*/_*' \
        -not -path '*/.pytest_cache/*' \
        -not -path '*/__pycache__/*' \
        -not -path '*/evals/*' \
        | sort
)

if [[ ${#SKILL_FILES[@]} -eq 0 ]]; then
    printf "%b\n" "${YELLOW}⚠${NC} No skill markdown files found (continuing with docs)."
fi

current_skill_file=""
file_broken=0
file_format_errors=0
is_skill_md=0

# Process all files with a single awk call.
# Format: FILENAME:LINE_NUM:IN_REF:CONTENT

lines_array=()
if [[ ${#SKILL_FILES[@]} -gt 0 ]]; then

old_opts="$-"
old_ifs="$IFS"
set -f
IFS=$'\n'
# Fenced code blocks are skipped. Documentation about writing markdown — readme-best-practices,
# skill-creator, migration-refactoring — quotes sample links on purpose, and a checker that reads
# them as references reports failures against text that was never a reference. The fence state
# resets at each file so one unbalanced block cannot suppress the rest of the scan.
lines_array=($(awk -- '
    BEGIN { in_ref = 0; fence = 0 }
    FNR == 1 { in_ref = 0; fence = 0; print FILENAME ":0:0:__START__" }
    /^[[:space:]]*(```|~~~)/ { fence = 1 - fence; next }
    fence { next }
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
                printf "  ${GREEN}✓${NC} %s: All links valid\n" "${current_skill_file#"$REPO_ROOT"/}"
            fi
        fi
        current_skill_file="$skill_file"
        file_broken=0
        file_format_errors=0
        FILES_CHECKED=$((FILES_CHECKED + 1))
        # link_base is the directory a renderer would resolve this file's relative links from.
        skill_dir="${skill_file%/*}"
        if [[ "${skill_file##*/}" == "SKILL.md" ]]; then
            is_skill_md=1
        else
            is_skill_md=0
        fi
        # Skip processing for the start-of-file marker
        [[ "$line_num" == "0" ]] && continue
    fi

    # Track if we're in the References section
    if is_references_header "$line"; then
        continue
    elif is_section_header "$line"; then
        continue
    fi

    # The References-section format rule, the backtick-path form and the deprecated @reference
    # rule are SKILL.md authoring conventions, so they stay scoped to SKILL.md. In a companion
    # file a backticked `references/foo.md` is prose naming a skill-root path (that is how the
    # skill lists its own references), which is not the same claim as a clickable link.
    if [[ "$is_skill_md" -eq 1 ]]; then
        # Check reference format (only in References section)
        if [[ "$in_references" -eq 1 ]]; then
            if ! check_reference_format "$line" "$line_num" "$skill_file" "$skill_dir"; then
                FORMAT_ERRORS=$((FORMAT_ERRORS + 1))
                file_format_errors=1
            fi
        fi
    fi

    # Find all markdown links in this line.
    #
    # Inline code spans are removed first: `[![...](img)](url)` inside backticks is literal text
    # that a renderer never turns into a link, so treating it as a reference invents breakage in
    # docs about writing docs. $line itself stays intact for the backtick-path rules below, which
    # depend on seeing the backticks.
    temp_line="${line//\`[^\`]*\`/}"
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

    if [[ "$is_skill_md" -eq 1 ]]; then
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
    fi
done

    # Final report for the last skill markdown file
    if [[ -n "$current_skill_file" ]]; then
        if [[ $file_broken -eq 0 && $file_format_errors -eq 0 ]]; then
            printf "  ${GREEN}✓${NC} %s: All links valid\n" "${current_skill_file#"$REPO_ROOT"/}"
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
