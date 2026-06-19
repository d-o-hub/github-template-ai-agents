# EU AI Act Compliance Logging for Chatbot

## Risk Classification

Chatbots interacting with users fall under **Limited Risk** (Article 50) per Regulation (EU) 2024/1689.

## Required Compliance Measures

### 1. AI Interaction Disclosure (Art. 50.1)

**First-contact disclosure**: Users must be informed they are interacting with an AI system.

```typescript
const DISCLOSURE_MESSAGE = "I am an AI assistant. Your conversation may be logged for compliance and quality purposes.";
```

### 2. Synthetic Content Marking (Art. 50.2)

Mark AI-generated responses as such.

### 3. Transparency Logging (Art. 12)

Log all AI inference operations with the following structure:

```typescript
interface AIActLogEntry {
  timestamp: string;           // ISO 8601 format
  systemId: string;            // Unique chatbot identifier
  operation: "ai_inference";   // Operation type
  inputData: {
    source: string;            // "user_request"
    hash: string;              // SHA-256 hash of input
    description: string;       // Brief description of input
  };
  outputData: {
    result: string;            // AI response (or hash for privacy)
    confidence?: number;       // Model confidence if available
  };
  humanOversight?: {
    reviewerId: string;        // Human reviewer identifier
    decision: "approved" | "rejected" | "modified";
    timestamp: string;
  };
  retentionUntil: string;      // Minimum 6 months from timestamp
}
```

## Implementation Example

```typescript
import crypto from "crypto";

class EUAIActChatbotLogger {
  private systemId: string;
  private retentionMonths: number = 6;

  constructor(systemId: string) {
    this.systemId = systemId;
  }

  private generateHash(data: string): string {
    return `sha256:${crypto.createHash("sha256").update(data).digest("hex")}`;
  }

  private getRetentionDate(): string {
    const date = new Date();
    date.setMonth(date.getMonth() + this.retentionMonths);
    return date.toISOString();
  }

  logInference(userInput: string, aiResponse: string): AIActLogEntry {
    const entry: AIActLogEntry = {
      timestamp: new Date().toISOString(),
      systemId: this.systemId,
      operation: "ai_inference",
      inputData: {
        source: "user_request",
        hash: this.generateHash(userInput),
        description: `User query (${userInput.length} chars)`,
      },
      outputData: {
        result: aiResponse,
      },
      retentionUntil: this.getRetentionDate(),
    };

    // Persist to audit log (database, file, or logging service)
    this.persistLog(entry);
    return entry;
  }

  private persistLog(entry: AIActLogEntry): void {
    // Implementation: write to database, audit log file, or logging service
    console.log("[EU-AI-ACT-AUDIT]", JSON.stringify(entry));
  }

  getDisclosureMessage(): string {
    return "I am an AI assistant. This interaction is logged for EU AI Act compliance (Regulation 2024/1689).";
  }
}
```

## Compliance Checklist

| Requirement | Article | Status |
|-------------|---------|--------|
| AI interaction disclosure at first contact | Art. 50.1 | Required |
| Synthetic content marking | Art. 50.2 | Required |
| Automatic logging of AI operations | Art. 12 | Required |
| 6-month log retention | Art. 19 | Required |
| Provider contact information | Art. 50 | Required |

## Key References

- **Article 12**: Automatic logging requirements
- **Article 14**: Human oversight design
- **Article 50**: Transparency and disclosure obligations
- **Article 19**: Log retention (minimum 6 months)

## Next Steps

1. Implement the `EUAIActChatbotLogger` class in your chatbot codebase
2. Ensure first-message includes AI disclosure
3. Configure audit log persistence (database or file-based)
4. Set up log retention policy (minimum 6 months)
5. Document provider contact information in your service
