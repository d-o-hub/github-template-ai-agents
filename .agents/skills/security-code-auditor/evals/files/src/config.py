"""Eval fixture: where configuration values belong.

The hardcoded-secrets eval asserts the agent reports every credential that is
committed rather than sourced from the environment, and does not stop at the
first one.

Two committed credentials appear below, because two is the interesting case:
an agent that flags only the most obvious assignment has not done the audit.

The literals are deliberately unremarkable. An earlier draft used a realistic
payment-provider key, which GitHub push protection blocked outright. A template
must not teach adopters to allowlist a secret in order to ship a fixture, and a
credential that looks real is not needed to exercise "find the hardcoded
credential" -- the assignment and the missing os.environ lookup are the signal.

Values a scanner treats as credentials are named in the docstring instead:

    a live-mode payment provider key
    a database connection URI with an inline password
    a PEM private key header
"""

import os

API_BASE_URL = "https://internal-api.example.com/v2"

# Correctly sourced: nothing to report.
DATABASE_URL = os.environ["DATABASE_URL"]

# Two committed values the eval expects the agent to flag, and to rank below the
# fact that both should come from the environment.
#
# Neither name contains "password"/"secret"/"token": Bandit B105 and Prospector
# key off the identifier, not the value, so a variable named *_PASSWORD is
# reported as a hardcoded password purely for being named that. The point of the
# fixture is that a committed credential is a finding whoever reports it.
LEGACY_ADMIN_CREDENTIAL = "demo-only-placeholder-value"
SESSION_SIGNING_VALUE = "insecure-default-signing-value"

DEBUG = os.environ.get("DEBUG", "false").lower() == "true"

ALLOWED_ORIGINS = ["*"]