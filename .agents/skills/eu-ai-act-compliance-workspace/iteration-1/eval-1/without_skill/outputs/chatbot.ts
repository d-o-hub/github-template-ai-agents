import { ComplianceLogger, ChatbotConfig } from "./compliance-logger";

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
