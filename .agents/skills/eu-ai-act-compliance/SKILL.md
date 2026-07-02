---
name: eu-ai-act-compliance
description: EU AI Act compliance logging and requirements. Use this skill when ensuring transparency, human oversight, and record-keeping per Regulation (EU) 2024/1689 — even if they just say "add compliance logging" or "make sure this is EU AI Act compliant". Not for security-code-auditor, privacy-first.
version: "0.2.10"
category: compliance
metadata:
  author: <ORG_NAME>
  spec: agentskills.io
  regulation: Regulation (EU) 2024/1689
  effective_date: 2026-08-02
license: MIT
---

# EU AI Act Compliance

## When to Use

- User asks to ensure EU AI Act compliance for logging or transparency
- Need to implement human oversight or record-keeping per Regulation (EU) 2024/1689
- Even if they just say "add compliance logging" or "make sure this is EU AI Act compliant"

## Quick Start

```typescript
import { AIActLogger } from "./eu-ai-act-compliance";

const logger = new AIActLogger({
  systemId: "<PROJECT_ID>",
  providerName: "<ORG_NAME>",
  riskClassification: "limited_risk",
});

await logger.logOperation({
  operation: "ai_inference",
  inputData: { source: "user_request", hash: "sha256:abc123..." },
  outputData: { result: "example_result", confidence: 0.85 },
  humanOversight: { reviewerId: "user_123", decision: "approved", timestamp: new Date().toISOString() },
});
```

## Core Concepts

| Concept | Article | Description |
|---------|---------|-------------|
| Automatic Logging | Art. 12 | Record events over system lifetime |
| Transparency | Art. 50 | Disclose AI interaction to users |
| Human Oversight | Art. 14 | Enable human intervention |
| Data Governance | Art. 10 | Document training/validation data |
| Retention | Art. 19 | Keep logs minimum 6 months |

## Risk Classification

### Limited Risk (Article 50)

Systems interacting with natural persons must:
- Disclose AI interaction at first contact (Art. 50.1).
- Mark synthetic content as AI-generated (Art. 50.2).

### High Risk (Chapter III, Articles 8-17)

Systems in Annex III (recruitment, credit scoring, etc.) require:
- Risk management (Art. 9) & Data governance (Art. 10).
- Technical documentation (Art. 11) & Automatic logging (Art. 12).
- Human oversight design (Art. 14) & CE marking (Art. 48).

## Logging Requirements (Article 12)

```typescript
interface AIActLogEntry {
  timestamp: string; // ISO 8601
  systemId: string;
  operation: string;
  inputData: { source: string; hash: string; description: string };
  outputData: { result: string; confidence?: number; explanation?: string };
  humanOversight?: { reviewerId: string; decision: "approved" | "rejected" | "modified"; timestamp: string };
  retentionUntil: string; // Min 6 months
}
```

## Compliance Checklist

- [ ] AI interaction disclosure implemented (Art. 50.1).
- [ ] Synthetic content marking enabled (Art. 50.2).
- [ ] Provider contact information published.
- [ ] High-risk: Risk management & Data governance documented.
- [ ] High-risk: Automatic logging & 6-month retention configured.

## References

- `references/eu-ai-act-articles.md` - Key article analysis

## See Also

- `security-code-auditor` — General security audits
- `privacy-first` — Email/personal data prevention

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "Small change, no logging." | AI interactions fall under transparency (Art. 50). |
| "Oversight later." | Oversight-by-design is mandatory for high-risk (Art. 14). |

## Red Flags

- [ ] Deploying without interaction disclosure.
- [ ] High-risk systems without automated record-keeping.

## Voice & Context

- **Default**: `professional` + `blog`
- **Reference**: `voice-profiles` skill for definitions and auto-detection.
