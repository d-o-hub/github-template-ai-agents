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
