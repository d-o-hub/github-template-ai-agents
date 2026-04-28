# Pact CLI Reference

## pact-stub-server
Create a mock server from a Pact file. Useful for frontend development without a real backend.
```bash
pact-stub-server --file contracts/pacts/consumer-provider.json --port 8080
```

## pact_verifier_cli
Verify a provider against Pact files.
```bash
pact_verifier_cli \
  --file contracts/pacts/consumer-provider.json \
  --provider-base-url http://localhost:8080 \
  --loglevel info
```

## pact-mock-service
(Ruby/Legacy) Standalone service to manage mock servers.
```bash
pact-mock-service start --port 1234 --pact-dir ./pacts
```
