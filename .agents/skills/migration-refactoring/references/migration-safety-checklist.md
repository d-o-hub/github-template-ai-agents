# Migration Safety Checklist

Standalone runbook: work through it before, during, and after any migration. Reference material lives in `migration-catalog.md`.

## Pre-Migration Safety Verification

### System Health

- [ ] All services passing health checks
- [ ] Error rates below SLO for 7 days
- [ ] Latency p99 within acceptable range
- [ ] Resource utilization under 70%
- [ ] Database replication lag < 1 second

### Data Verification

- [ ] Backup verified and restorable
- [ ] Data consistency checks passing
- [ ] Schema migration scripts tested
- [ ] Rollback scripts tested
- [ ] Data migration dry-run completed

### Monitoring & Alerting

- [ ] Dashboards updated for new metrics
- [ ] Alert thresholds configured
- [ ] PagerDuty/Opsgenie integration verified
- [ ] Runbooks updated and accessible
- [ ] Escalation paths confirmed

### Feature Flags

- [ ] Kill switches configured and tested
- [ ] Gradual rollout stages defined
- [ ] Auto-rollback criteria documented
- [ ] Feature flag dashboard accessible
- [ ] Emergency contacts updated

### Testing

- [ ] Shadow traffic analysis passing (>99% match rate)
- [ ] Canary metrics within tolerance
- [ ] Load testing completed at 2x expected traffic
- [ ] Chaos engineering scenarios passed
- [ ] Rollback procedure tested in staging

### Communication

- [ ] On-call team notified
- [ ] Stakeholders informed of migration window
- [ ] Status page prepared
- [ ] Rollback communication templates ready
- [ ] Post-monitoring plan shared

## Breaking-Change Analysis Gate

- [ ] API surface changes identified
- [ ] Behavior changes documented
- [ ] Deprecation timeline reviewed
- [ ] Security implications assessed

Record: services affected, lines of code impacted, test coverage affected, estimated effort, risk level (Critical/High/Medium/Low).

## Migration Planning Template

### Strategy

- [ ] Gradual rollout with feature flags
- [ ] Blue-green deployment capability
- [ ] Rollback window defined (max 4 hours)
- [ ] Data compatibility verified

### Testing

- [ ] Unit tests updated
- [ ] Integration tests pass
- [ ] Contract tests verified
- [ ] Load tests completed
- [ ] Chaos engineering scenarios tested

### Monitoring Plan

- Error rate threshold: ____%
- Latency threshold: ____ ms
- Business metric baselines recorded
- Alerting rules configured

### Rollback Plan

- Previous version: ____
- Rollback time: ____ minutes
- Data compatibility: Y/N
- Rollback validation steps listed

### Timeline

- Testing start / staging deploy / production rollout dates set
- Monitoring period: ____ days
- Completion date: ____

## Language Migration Checklists

### Python 3.11 → 3.12

- [ ] Audit `distutils` usage → setuptools/hatchling
- [ ] Check type annotation compatibility (PEP 695, mypy >= 1.6)
- [ ] Review f-string usage for quote conflicts (PEP 701)
- [ ] Fix `locals()` iteration in comprehensions (PEP 709): snapshot first
- [ ] Remove dead imports: `asynchat`, `asyncore`, `imp`, `smtpd`
- [ ] CI/CD updated to Python 3.12 (`pyupgrade --py312-plus`, `ruff --target-version py312`)
- [ ] Docker base images, `requirements.txt`/`pyproject.toml`, pre-commit hooks updated

### Node.js 18 → 20

- [ ] Replace `url.parse()` with `URL` API
- [ ] Audit `process.exit()` calls — numeric codes only
- [ ] Update ESM loaders for dedicated-thread behavior
- [ ] Add `version` parameter to WASI constructor
- [ ] Adopt permission model flags where relevant
- [ ] Switch to built-in test runner (`node --test`)
- [ ] Verify native module compatibility

### Java 17 → 21

- [ ] Check for preview feature usage (string templates: `--enable-preview`)
- [ ] Audit `synchronized` blocks in I/O paths → `ReentrantLock` for virtual threads
- [ ] Replace `instanceof` chains with switch patterns
- [ ] Never pool virtual threads — `newVirtualThreadPerTaskExecutor()`
- [ ] Update Maven/Gradle and Spring Boot to 3.2+ (javax → jakarta)
- [ ] Benchmark virtual vs platform threads; monitor pinning (`-Djdk.tracePinnedThreads=full`)

## Rollout & Rollback Gates

Do not proceed past a gate with an unchecked box:

1. **Expose gate** — shadow match rate > 99%, health checks pass, dashboards live.
2. **Stage-advance gate** — current stage success criteria met; no emergency condition (error > 10%, p99 > 5s, business metric < 50% baseline) active.
3. **Data flip gate (READ_NEW)** — backfill complete; batch verification shows zero mismatches.
4. **Contract gate (drop old schema)** — full verification passed; rollback window still open.
5. **Close gate** — TTR targets hold (critical < 2 min, perf < 5 min, data < 15 min), post-rollback post-mortem within 24h of any incident.
