#!/usr/bin/env bash
# Historical default-skip policy, shared by setup and validation.
# Optional *pack* membership is documentation, not a reason to skip new skills.
# Exported to sourcing consumers; this manifest does not read the array itself.
# shellcheck disable=SC2034
SKILLS_OPTIONAL=(
  "eu-ai-act-compliance"
  "durable-objects"
  "reader-ui-ux"
  "document-rendering-and-locators"
  "pwa-offline-sync"
  "cloudflare-worker-api"
  "codacy"
  "lifecycle-management"
)
