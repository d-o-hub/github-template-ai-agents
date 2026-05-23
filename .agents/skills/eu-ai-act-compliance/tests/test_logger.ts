import { AIActLogger } from "../eu-ai-act-compliance";

/**
 * Basic conceptual verification for the AIActLogger.
 */
async function testLogger() {
  const logger = new AIActLogger({
    systemId: "test-system",
    providerName: "test-org",
    riskClassification: "limited_risk",
  });

  await logger.logOperation({
    operation: "test_op",
    inputData: { source: "test_src", hash: "sha256:123" },
    outputData: { result: "test_res" },
  });

  console.log("Logger test completed");
}

if (require.main === module) {
  testLogger().catch(console.error);
}
