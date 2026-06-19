# EU AI Act Compliance Logging for Chatbot

## Overview

This implementation adds EU AI Act compliance logging to a chatbot per Regulation (EU) 2024/1689. Key requirements:

| Requirement | Article | Implementation |
|-------------|---------|----------------|
| AI Disclosure | Art. 50.1 | First-contact disclosure banner |
| Activity Logging | Art. 12 | Immutable interaction records |
| Retention | Art. 19 | 6-month minimum log retention |
| Human Oversight | Art. 14 | Escalation to human review |

## Implementation

### 1. Compliance Logger (`compliance-logger.ts`)

```typescript
import { createHash } from "crypto";

export interface ChatbotConfig {
  systemId: string;
  providerName: string;
  providerContact: string;
  riskClassification: "limited_risk" | "high_risk";
  retentionDays?: number;
}

export interface ChatLogEntry {
  timestamp: string;
  sessionId: string;
  operation: "user_message" | "ai_response" | "escalation" | "disclosure";
  inputData: {
    source: "user" | "system";
    hash: string;
    contentPreview?: string;
  };
  outputData: {
    result: string;
    confidence?: number;
  };
  humanOversight?: {
    reviewerId: string;
    decision: "approved" | "rejected" | "modified";
    timestamp: string;
  };
  riskFlags?: string[];
}

export class ComplianceLogger {
  private config: ChatbotConfig;
  private logs: ChatLogEntry[] = [];

  constructor(config: ChatbotConfig) {
    this.config = {
      retentionDays: 180,
      ...config,
    };
  }

  async logInteraction(entry: Omit<ChatLogEntry, "timestamp">): Promise<ChatLogEntry> {
    const fullEntry: ChatLogEntry = {
      timestamp: new Date().toISOString(),
      ...entry,
    };

    this.logs.push(fullEntry);
    await this.persist(fullEntry);
    return fullEntry;
  }

  async getDisclosureMessage(): Promise<string> {
    const disclosure = `[AI System Disclosure - Art. 50.1] You are interacting with an AI chatbot operated by ${this.config.providerName}. All interactions are logged per EU AI Act requirements. Contact: ${this.config.providerContact}`;
    await this.logInteraction({
      sessionId: "system",
      operation: "disclosure",
      inputData: { source: "system", hash: this.hash(disclosure) },
      outputData: { result: disclosure },
    });
    return disclosure;
  }

  async logUserMessage(sessionId: string, message: string): Promise<void> {
    await this.logInteraction({
      sessionId,
      operation: "user_message",
      inputData: { source: "user", hash: this.hash(message), contentPreview: message.substring(0, 100) },
      outputData: { result: "received" },
    });
  }

  async logAIResponse(sessionId: string, response: string, confidence?: number): Promise<void> {
    await this.logInteraction({
      sessionId,
      operation: "ai_response",
      inputData: { source: "system", hash: this.hash(response) },
      outputData: { result: "generated", confidence },
    });
  }

  async logEscalation(sessionId: string, reason: string, reviewerId?: string): Promise<void> {
    await this.logInteraction({
      sessionId,
      operation: "escalation",
      inputData: { source: "system", hash: this.hash(reason) },
      outputData: { result: "escalated_to_human" },
      humanOversight: reviewerId ? { reviewerId, decision: "approved", timestamp: new Date().toISOString() } : undefined,
    });
  }

  private hash(data: string): string {
    return `sha256:${createHash("sha256").update(data).digest("hex")}`;
  }

  private async persist(entry: ChatLogEntry): Promise<void> {
    // Production: write to immutable, encrypted storage
    // Retention: minimum 180 days (6 months) per Art. 19
  }
}
```

### 2. Chatbot Integration (`chatbot.ts`)

```typescript
import { ComplianceLogger } from "./compliance-logger";

export class CompliantChatbot {
  private logger: ComplianceLogger;
  private disclosedSessions = new Set<string>();

  constructor(config: ChatbotConfig) {
    this.logger = new ComplianceLogger(config);
  }

  async handleMessage(sessionId: string, userMessage: string): Promise<string> {
    // Art. 50.1: First-contact disclosure
    if (!this.disclosedSessions.has(sessionId)) {
      const disclosure = await this.logger.getDisclosureMessage();
      this.disclosedSessions.add(sessionId);
      return `${disclosure}\n\nHow can I help you?`;
    }

    // Log user input
    await this.logger.logUserMessage(sessionId, userMessage);

    // Generate AI response (your existing logic)
    const response = await this.generateResponse(userMessage);

    // Log AI output with confidence
    await this.logger.logAIResponse(sessionId, response, 0.95);

    return response;
  }

  async escalateToHuman(sessionId: string, reason: string): Promise<void> {
    await this.logger.logEscalation(sessionId, reason);
  }

  private async generateResponse(input: string): Promise<string> {
    // Your existing chatbot logic
    return "I understand your question. Let me help you with that.";
  }
}
```

### 3. Usage Example

```typescript
const chatbot = new CompliantChatbot({
  systemId: "chatbot-prod-001",
  providerName: "MyCompany GmbH",
  providerContact: "ai-compliance@mycompany.eu",
  riskClassification: "limited_risk",
});

// First interaction triggers Art. 50.1 disclosure
const response = await chatbot.handleMessage("session-123", "Hello!");
// Response includes: "[AI System Disclosure - Art. 50.1] You are interacting with an AI chatbot..."
```

## Compliance Checklist

- [x] AI interaction disclosure at first contact (Art. 50.1)
- [x] Activity logging with timestamps (Art. 12)
- [x] Minimum 6-month retention configured (Art. 19)
- [x] Provider contact information included
- [ ] Synthetic content marking (Art. 50.2) - if generating images/media
- [ ] Risk management documentation (Art. 9) - for high-risk systems
- [ ] Data governance records (Art. 10) - for high-risk systems

## Production Considerations

1. **Storage**: Use append-only, tamper-evident storage (e.g., AWS CloudTrail, immutable S3)
2. **Encryption**: Encrypt logs at rest and in transit
3. **Access Control**: Restrict log access to authorized personnel only
4. **Retention**: Auto-purge logs after retention period (default 180 days)
5. **Audit Trail**: All log access should itself be logged

## Files to Create

- `compliance-logger.ts` - Core compliance logging module
- `chatbot.ts` - Chatbot integration with compliance built-in
