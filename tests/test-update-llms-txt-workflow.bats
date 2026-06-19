#!/usr/bin/env bats

@test "llms-txt workflow uses fixed auto/regenerate-llms-txt branch" {
    grep -q "BRANCH=\"auto/regenerate-llms-txt\"" .github/workflows/update-llms-txt.yml
}

@test "llms-txt workflow omits skip ci from branch commit (allows checks to run)" {
    grep -q 'commit -m "ci: regenerate llms.txt and llms-full.txt"' .github/workflows/update-llms-txt.yml
    ! grep -q 'commit -m "ci: regenerate llms.txt and llms-full.txt \[skip ci\]"' .github/workflows/update-llms-txt.yml
}

@test "llms-txt workflow uses skip ci in merge subject" {
    grep -q 'subject "ci: regenerate llms.txt and llms-full.txt \[skip ci\]"' .github/workflows/update-llms-txt.yml
}

@test "llms-txt workflow reuses existing PR" {
    grep -q "EXISTING_PR" .github/workflows/update-llms-txt.yml
    grep -q "Reusing existing PR" .github/workflows/update-llms-txt.yml
}

@test "llms-txt workflow performs auto-merge" {
    grep -q 'gh pr merge "$NEW_PR"' .github/workflows/update-llms-txt.yml
    grep -q "\-\-auto" .github/workflows/update-llms-txt.yml
    grep -q "\-\-squash" .github/workflows/update-llms-txt.yml
    grep -q "\-\-delete-branch=false" .github/workflows/update-llms-txt.yml
}

@test "llms-txt workflow uses force push to fixed branch" {
    grep -q 'git push -f origin "$BRANCH"' .github/workflows/update-llms-txt.yml
}

@test "llms-txt workflow triggers on main push with correct paths" {
    grep -q "AGENTS.md" .github/workflows/update-llms-txt.yml
    grep -q "README.md" .github/workflows/update-llms-txt.yml
    grep -qF '.agents/skills/*/SKILL.md' .github/workflows/update-llms-txt.yml
}

@test "llms-txt workflow has workflow_dispatch trigger" {
    grep -q "workflow_dispatch" .github/workflows/update-llms-txt.yml
}
