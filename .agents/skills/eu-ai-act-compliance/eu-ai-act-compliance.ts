/**
 * EU AI Act Compliance Logger
 * Provides automated record-keeping per Article 12 of Regulation (EU) 2024/1689.
 */

export interface AIActConfig {
  systemId: string;
  systemVersion?: string;
  providerName: string;
  providerContact?: string;
  intendedPurpose?: string;
  riskClassification: "limited_risk" | "high_risk";
  retentionDays?: number;
}

export interface AIActLogEntry {
  timestamp: string;
  operation: string;
  inputData: {
    source: string;
    hash: string;
    description?: string;
    metadata?: Record<string, unknown>;
  };
  outputData: {
    result: string;
    confidence?: number;
    explanation?: string;
  };
  humanOversight?: {
    reviewerId: string;
    decision: "approved" | "rejected" | "modified" | "overridden";
    timestamp: string;
    modificationNotes?: string;
  };
  riskFlags?: string[];
}

export class AIActLogger {
  private config: AIActConfig;

  constructor(config: AIActConfig) {
    this.config = {
      systemVersion: "1.0.0",
      retentionDays: 180, // Minimum 6 months
      ...config,
    };
  }

  /**
   * Logs an AI operation to satisfy Article 12 requirements.
   * In a real implementation, this would write to a secure, immutable storage.
   */
  async logOperation(entry: Omit<AIActLogEntry, "timestamp">): Promise<void> {
    const fullEntry: AIActLogEntry = {
      timestamp: new Date().toISOString(),
      ...entry,
    };

    // For demonstration, we just log to console or a mock storage
    console.log(`[EU-AI-ACT-LOG] [${this.config.systemId}] ${JSON.stringify(fullEntry)}`);

    // In production, ensure storage is tamper-evident and encrypted.
    return Promise.resolve();
  }
}
