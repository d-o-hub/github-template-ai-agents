# Migration Catalog

Consolidated migration knowledge: patterns, dependency analysis, safety, rollback, and breaking changes. Checklists live in `migration-safety-checklist.md`.

## 1. Migration Patterns

### 1.1 Strangler Fig (2025-2026)

Four high-level activities (Fowler, Aug 2024):

1. Understand the outcomes you want to achieve
2. Decide how to break the problem up into smaller parts
3. Successfully deliver the parts
4. Change the organization to allow this to happen ongoing

Migration phases: `DISCOVERY` → `SEAM_IDENTIFICATION` → `INCREMENTAL_REPLACEMENT` → `COMPLETION`.

Rules:
- Route per business capability, not per URL; register legacy + modern handler per capability.
- Use consistent hashing on a stable routing key (user ID) so users stay on one side; never split a session across implementations.
- Fallback to the legacy handler on modern-handler error; count errors per capability.
- Increase rollout percentage only after a validation callback passes; cap at 100.

Anchor implementation:

```python
class StranglerRouter:
    def register_route(self, capability, legacy_handler, modern_handler,
                       rollout_percentage=0.0): ...

    def route_request(self, capability, context, routing_key=None):
        route = self.routes[capability]
        # Stable bucket per routing key: md5(key) % 100 + 1
        bucket = self._calculate_bucket(routing_key) if routing_key else 0
        if bucket < route['rollout_pct']:
            try:
                return route['modern'](context)   # count modern_calls
            except Exception:
                route['metrics']['errors'] += 1
                return route['legacy'](context)   # fallback on error
        return route['legacy'](context)

    def increase_rollout(self, capability, new_pct, validation_callback=None):
        if validation_callback and not validation_callback():
            raise MigrationValidationError(capability)
        self.routes[capability]['rollout_pct'] = min(new_pct, 100)
```

### 1.2 Branch by Abstraction

Create an abstraction layer, then swap implementations behind it.

1. Define an interface (ABC / protocol) covering the operations in flight.
2. Implement it twice: `Legacy*` (direct DB / monolith calls) and `Modern*` (service HTTP calls).
3. Route through a router that picks by feature flag; keep a dual-write mode for the transition window.
4. Migrate callers to the interface only; never let callers import a concrete implementation.

```python
class OrderServiceRouter:
    def create_order(self, order_data):
        use_modern = self.flags.is_enabled('orders-microservice')
        if self.dual_write_mode:
            legacy_result = self.legacy.create_order(order_data)
            try:
                modern_result = self.modern.create_order(order_data)
                self._verify_consistency(legacy_result, modern_result)
            except Exception as e:
                self._log_dual_write_error('create_order', order_data, e)
            return modern_result if use_modern else legacy_result
        return self.modern.create_order(order_data) if use_modern \
               else self.legacy.create_order(order_data)
```

### 1.3 Parallel Run

Run old and new systems concurrently to verify correctness without affecting users.

- Execute both concurrently; serve the legacy result to users.
- Compare with per-operation rules: `ignore_fields` (strip before compare) and `numeric_tolerance` (compare within epsilon); mismatched pairs → strict compare.
- Log every mismatch with operation, params, and both results; a mismatch is a defect signal, not a user-facing failure.

```python
result = ParallelRunResult(
    legacy_result, modern_result,
    legacy_latency_ms, modern_latency_ms,
    matches=len(differences) == 0, differences=differences)
if not result.matches:
    self._log_mismatch(operation, params, result)
```

### 1.4 Change Data Capture (CDC)

Keep legacy and modern data stores synchronized during database migration.

Event shape: `table`, `operation` (INSERT/UPDATE/DELETE), `before`, `after`, `timestamp`, `transaction_id`.

Rules:
- Process events in transaction order; handle INSERT, UPDATE, DELETE separately.
- Transform via a `SchemaTransformer`: register per-source-table `target_table`, `column_mappings`, and per-column `transforms` (callables); apply transform before writing.
- Unmapped source tables pass through unchanged (flag this — silent passthrough hides missing mappings).

```python
class SchemaTransformer:
    def register_mapping(self, source_table, target_table,
                         column_mappings, transformations=None):
        self.mappings[source_table] = {
            'target_table': target_table,
            'columns': column_mappings,
            'transforms': transformations or {},
        }
```

### 1.5 Expand-Contract Database Migration

Zero-downtime schema evolution, ordered phases:

| Phase | Action | Invariant |
|---|---|---|
| `EXPAND` | Add new tables/columns; compatibility views in old DB | Old code path fully functional |
| `DUAL_WRITE` | Enable dual-write flag; CDC from old→new catches missed writes | Old remains source of truth |
| `BACKFILL` | Migrate existing rows in batches (1000/ batch, cursor by id) | Verify every batch before advancing |
| `READ_NEW` | Flip reads via staged flag rollout (1/5/10/50/100%) | Rollback = flip flag back |
| `CONTRACT` | After consistency verification, drop old tables/views | Verify before drop; never drop blind |

Rules:
- Writes flow old→new during transition; reads switch only after backfill + verification.
- Each batch: transform, insert, then sample-verify before the cursor advances.
- Keep rollback capability through `READ_NEW`; old schema may be removed only in `CONTRACT`.

### 1.6 Dual-Write API Migration

- Write the legacy API first — it stays the source of truth; the new-API write is asynchronous and non-blocking.
- Swallow new-API failures into a logged error queue for replay; never fail the user request because the new API failed.
- After a successful pair of writes, verify consistency and log violations; always return the legacy result during migration.

```python
async def update_user(self, user_id, data):
    legacy_result = await self.old_api.update_user(user_id, data)  # truth
    try:
        new_result = await self.new_api.update_user(user_id, data)
    except Exception as e:
        self._log_new_api_error('update_user', user_id, data, e)
    else:
        if new_result and not self.checker.compare_user_update(legacy_result, new_result):
            self._log_consistency_violation('update_user', user_id,
                                            legacy_result, new_result)
    return legacy_result
```

### 1.7 Pattern Selection

| Pattern | When |
|---|---|
| Gradual migration (compat layer) | Cannot change all call sites at once |
| Feature flags | High-risk changes needing rollback capability |
| Strangler fig | Decomposing monoliths incrementally |
| Parallel implementation + sync | Zero-downtime migrations with data changes |
| Expand-contract | Database schema evolution with data transformation |
| CDC | Keeping two stores synchronized during transition |

## 2. Dependency Analysis

Build a directed graph of cross-file relationships before migrating: imports/includes, inheritance, interface implementations, function calls.

### 2.1 Python Import Analysis

Parse with `ast`; classify `sys.stdlib_module_names` as stdlib, in-project modules as local, the rest as third-party.

Must detect:
- `ast.Import` / `ast.ImportFrom` with line numbers and aliases
- Conditional imports: track whether the import sits inside `try`/`if` (soft dependency)
- Dynamic imports: `__import__()` and `importlib` calls with constant string arguments
- Relative imports: resolve `level` against the current module path
- Exports: `__all__` assignments (list/tuple of constants) plus public classes/functions (name not starting with `_`)
- Transitive impact: flood-fill from direct dependents; a changed module's blast radius includes all recursive importers

```python
for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        for alias in node.names:
            analysis.dependencies.add(alias.name.split('.')[0])
    elif isinstance(node, ast.ImportFrom):
        base = (self._resolve_relative_import(module_name, node.level, node.module)
                if node.level > 0 else (node.module or '').split('.')[0])
        if base:
            analysis.dependencies.add(base)
```

Build a `networkx.DiGraph`; compute `find_impacted_files(changed_module)` as transitive dependents, and cycles with `nx.simple_cycles`.

### 2.2 JavaScript/TypeScript Module Analysis

Parse with Babel (`sourceType: 'module'`, plugins: jsx, typescript, dynamicImport, topLevelAwait).

Must detect:
- ESM `ImportDeclaration` — record `importKind === 'type'` separately (type-only imports never break runtime)
- CommonJS `require('...')` calls with string literals
- Dynamic `import('...')` — record location; these edges are safe cycle-break points
- Exports: named declarations, re-exports, and default exports
- Resolve specifiers with aliases and extensions `.js`, `.jsx`, `.ts`, `.tsx`, `.json`
- Cycle detection: DFS with a recursion stack; on revisit capture `path.slice(cycleStart)`

```javascript
ImportDeclaration({ node }) {
  const isTypeOnly = node.importKind === 'type';
  // type-only imports route to typeOnlyImports, not runtime imports
}
CallExpression({ node }) {
  if (node.callee.type === 'Import') dynamicImports.push(node.arguments[0]?.value);
}
```

### 2.3 Circular Dependency Severity and Remediation

| Severity | Cycle shape | Impact |
|---|---|---|
| CRITICAL | Runtime import cycle | Import errors, infinite loops, cannot start |
| HIGH | Involves `__init__`/initialization or import side effects | Startup ordering issues |
| MEDIUM | Plain code cycle | Code smell, maintenance risk |
| LOW | Type-only cycle (TS) | IDE performance only, no runtime effect |

Remediation priority:
1. Break at type-only or dynamic-import edges first — they deferral-safe; rank candidates by fewest downstream dependents.
2. Fix patterns, applied to the chosen edge: dependency injection, extract an interface shared by both sides, or move the import inside a function (lazy import).

### 2.4 Service Dependency Manifest

Declare service-level relationships explicitly (type, criticality, timeouts, retries, circuit breakers, events):

```yaml
services:
  api-gateway:
    depends_on:
      - service: user-service
        type: http
        criticality: required
        timeout_ms: 5000
        retry_policy: exponential_backoff
      - service: payment-service
        type: http
        criticality: required
        circuit_breaker: true
    service_mesh: { enabled: true, mtls: true, traffic_split: { canary: 10, stable: 90 } }
  user-service:
    depends_on:
      - service: postgres
        type: database
        criticality: required
      - service: redis
        type: cache
        criticality: optional           # optional deps must have degradation paths
    events:
      produces:
        - topic: user.created
          schema: user-events/v1
  order-service:
    depends_on:
      - service: user-service
        type: http
        async: true                      # async edges tolerate provider slowness
    circuit_breaker: { failure_threshold: 5, recovery_timeout_ms: 30000 }
```

Rules:
- Every `criticality: required` edge needs a failure mode (circuit breaker, timeout, or fail-fast).
- Event contracts (topic + schema version) are dependencies too — count breaking schema changes as breaking changes.
- Consumers must be listed so a provider change has a known blast radius.

### 2.5 Dependency Visualization

Graphviz conventions: node fill red = unhealthy, orange = critical, yellow = in canary, lightblue = default; edges bold-blue = database, dashed-green = cache, dotted-purple = async, solid = http; optional criticality renders dashed. Node size scales with dependent count (>5 dependents red, >2 orange).

### 2.6 Database Schema Dependencies

PostgreSQL recursive foreign-key tree (depth-capped):

```sql
WITH RECURSIVE dependency_tree AS (
    SELECT tc.table_schema, tc.table_name, kcu.column_name,
           ccu.table_name AS foreign_table_name, 1 AS depth
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage ccu
        ON ccu.constraint_name = tc.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
    UNION ALL
    SELECT dt.table_schema, dt.table_name, dt.column_name,
           ccu.table_name, dt.depth + 1
    FROM dependency_tree dt
    JOIN information_schema.table_constraints tc
        ON tc.table_name = dt.foreign_table_name
    JOIN information_schema.constraint_column_usage ccu
        ON ccu.constraint_name = tc.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND dt.depth < 10                      -- prevent infinite recursion
)
SELECT * FROM dependency_tree ORDER BY depth, table_schema, table_name;
```

### 2.7 Migration Ordering

Topological sort (Kahn's algorithm): edge `depends_on -> table`; migrate in-order.

- Seed the queue with in-degree-0 tables; decrement dependents as tables migrate.
- If the output covers fewer nodes than the graph, dependencies are cyclic — report the cycle list, do not proceed.
- Tables whose dependencies are all satisfied can migrate in parallel (group them to batch the migration).

```python
queue = deque(t for t in nodes if in_degree[t] == 0)
while queue:
    table = queue.popleft()
    result.append(table)
    for dependent in graph[table]:
        in_degree[dependent] -= 1
        if in_degree[dependent] == 0:
            queue.append(dependent)
if len(result) != len(nodes):
    raise ValueError(f"Circular dependencies: {find_cycles()}")
```

FK rule of thumb: migrate referenced tables before referencing tables; reverse (drop) order is the mirror image.

### 2.8 CI/CD Smart Test Selection

Per PR: build the dependency graph, find impacted modules from changed files, select and run only their tests.

```yaml
- name: Analyze Code Changes
  run: |
      CHANGED_FILES=$(git diff --name-only HEAD^ HEAD | grep '\.py$' || true)
      python scripts/build_dependency_graph.py --output graph.json
      IMPACTED=$(python scripts/find_impacted.py \
        --graph graph.json --changed-files "$CHANGED_FILES" --output json)
- name: Run Impacted Tests
  run: pytest $TESTS --cov=src --cov-report=xml --cov-fail-under=80
- name: Check New Dependencies
  run: python scripts/check_new_dependencies.py --baseline main
```

Also: warn (don't fail) on circular dependencies introduced by the change; render the impacted subgraph as an artifact on failure; require full history (`fetch-depth: 0`) for accurate diffs.

### 2.9 Dependency Best Practices

- Graph-store (Neo4j) the graph for monorepos with 1000+ modules.
- Health score per dependency: reverse-dependency count, change frequency, test coverage, cycle involvement.
- Consumer-driven contract tests for service dependencies.
- Dependency freeze windows during critical migration periods.
- Surface blast radius automatically in PRs; track dependency debt as a metric.

### 2.10 Tools

| Tool | Language | Purpose |
|------|----------|---------|
| `pydeps`, `importlab` | Python | Import graph |
| `pipdeptree` | Python | Dependency tree visualization |
| `dependency-cruiser`, `madge` | JS/TS | Graph + circular dependency detection |
| `nx` | JS/TS | Monorepo dependency graph |
| `npm ls` | JavaScript | Dependency tree |
| `jdeps`, `classycle` | Java | Class dependency analysis |
| `godepgraph`, `crane` | Go | Dependency graph |
| `cargo-deps`, `cargo-tree` | Rust | Dependency visualization |
| `deptrac` | PHP | Layer dependency rules |
| `dependency-check`, `snyk` | Multi | Security vulnerability scanning |

## 3. Safety Patterns

### 3.1 Shadow Testing

Serve the old result to users while exercising the new implementation on the same traffic.

Rules:
- Execute both implementations concurrently; the user always receives the old result.
- Fingerprint each request (sha256 of canonicalized JSON, truncated) to deduplicate and correlate distributed traces (span attributes: request_id, match, anomaly_score).
- Score each pair for anomalies; alert when anomaly score > 0.9. Features to extract: latency ratio, response size diff, status-code match, payload structure match, request complexity.
- Buffer results (cap ~10k) and report statistically: match rate, anomaly rate, mean latency improvement, promote/hold recommendation.
- Health gate: require >99% match rate over a window before any exposure to real traffic.

```python
old_result, old_latency = await self._call_with_timing(self.old, req, ctx)
new_result, new_latency = await self._call_with_timing(self.new, req, ctx)
features = self._extract_features(request, old_result, new_result,
                                 old_latency, new_latency)
if (anomaly_score := self.anomaly_detector.score(features)) > 0.9:
    self._alert_anomaly(result)
return old_result                                  # always the old result
```

### 3.2 Canary Analysis with Statistical Significance

Use statistical tests, not raw thresholds; minimum 100 samples before judging.

Error rate — two-proportion z-test:
- pooled proportion `p_pool = (c_err + b_err) / (c_req + b_req)`
- standard error `se = sqrt(p_pool*(1-p_pool)*(1/c_req + 1/b_req))`, `z = (p1 - p2)/se`
- PASS iff `|z| < z_critical` (confidence 0.95) **and** canary rate <= 1.1x baseline
- CRITICAL (rollback) iff canary error rate > 1.5x baseline (with baseline > 0.1%)

Latency p99 — Mann-Whitney U (non-parametric):
- needs >= 10 samples per side; PASS iff `p_value > alpha` **and** median canary <= 1.2x median baseline
- CRITICAL iff median regression > 500ms

Decision: any critical check → `rollback`; all pass plus sufficient samples (scale up requirement if observed effect > 1%) → `promote`; otherwise `continue` monitoring. Use SPRT for early stopping when the sequential evidence is decisive.

### 3.3 Feature Flags and Graduated Rollout

Toggle categories (Fowler): `release` (short-lived, trunk-based), `experiment` (A/B), `ops` (kill switches), `permissioning` (premium/alpha/beta).

Staged rollout schedule (default):

| Stage | Percentage | Duration |
|---|---|---|
| 1 | 1% | 30 min (internal) |
| 2 | 5% | 60 min |
| 3 | 10% | 60 min |
| 4 | 25% | 120 min |
| 5 | 50% | 120 min |
| 6 | 100% | — |

Rollout strategies: `percentage`, `cohort` (consistent user cohort), `canary` (multi-stage), `ring` (deployment rings).

Kill-switch priorities: CRITICAL 0s delay, HIGH 5s, MEDIUM 30s, LOW 120s.

Rules:
- Check feature dependencies are ready before starting a rollout; abort with `DependencyNotReadyError` otherwise.
- Monitor each stage (30s interval) against its success criteria; auto-advance on pass, emergency-kill on failure if `auto_rollback_on_failure`.
- Emergency-kill conditions (2-min window): error rate > 10%, latency p99 > 5s, or business/conversion metric < 50% of baseline.
- Emergency kill sequence: set percentage 0 → invalidate feature caches → page on-call with reason and priority.
- Auto-rollback criteria (per migration flag): error rate > 1% or p99 > 2000ms.

```python
async def _monitor_stage(self, feature, stage_idx, stage):
    while True:
        if (elapsed := since(start)) >= stage.duration_minutes * 60:
            metrics = await self._collect_stage_metrics(feature)
            if self._meets_criteria(metrics, stage.success_criteria):
                return await self._advance_stage(feature, stage_idx + 1)
            if stage.auto_rollback_on_failure:
                return await self.emergency_kill(feature, 'stage_criteria_not_met')
        if await self._check_emergency_conditions(feature):
            return await self.emergency_kill(feature, 'emergency_condition')
        await asyncio.sleep(30)
```

### 3.4 Circuit Breaker

States: `CLOSED` (normal) → `OPEN` (rejecting) → `HALF_OPEN` (probing recovery) → `CLOSED`.

Baseline parameters: failure threshold 5, recovery timeout 60s, half-open max calls 5; API-facing breakers may use half-open 3.

Rules:
- Failure in HALF_OPEN reopens the breaker immediately.
- Enough half-open successes (>= half_open_max_calls) close it; success in CLOSED decays the failure count.
- Adaptive thresholds over a rolling window (last ~100 calls): failure rate > 30% (high-failure environment) → lower threshold to 3 and recovery to 30s; rate < 10% → restore baseline.
- Raise `CircuitBreakerOpen` when OPEN or half-open calls exhausted; never let migration-period instability cascade.

### 3.5 Data Consistency Verification

During dual-write/dual-store migrations verify continuously:

- Per-write: fetch both records, transform old→new schema, compare field-by-field; any `_fetch_new` miss = `missing_in_new`.
- Tolerances per field: numeric `max_diff` (default 0.001), timestamp `max_seconds` (default 1s); outside tolerance = violation (record old/new values, severity, timestamp).
- Batch verification: iterate old store in batches (1000 default); track `total_checked`, `mismatches`, `missing_in_new`, `missing_in_old`.
- Alert on violations; a non-empty violation list blocks `READ_NEW`/`CONTRACT` phase advancement.

### 3.6 Automated Rollback Triggers

Trigger types: `error_rate`, `latency_percentile` (p99), `business_metric`, `infrastructure`, `security`, `manual`.

Rules:
- A trigger fires only after N consecutive violations inside its duration window — one bad minute must not roll back.
- Business-metric trigger compares current/baseline; violation when below threshold ratio.
- Staged rollback: cut to 50%, re-check after 30s; if still violated → 0% (full rollback) with critical alert.
- Log every rollback with trigger type, severity, and stage reached.

### 3.7 Migration Health Checks

Overall status: HEALTHY / DEGRADED / UNHEALTHY; proceed only when every check is HEALTHY or DEGRADED.

Checks (run concurrently):
1. Service health — old and new, 5s timeout; timeout = UNHEALTHY
2. Data consistency — sample compare; >99% = HEALTHY, >95% = DEGRADED, else UNHEALTHY
3. Dependency health — all declared `depends_on` targets reachable
4. Performance regression — latency vs baseline
5. Error budget — remaining budget per SLO
6. Business metrics — conversion/engagement vs baseline

Any UNHEALTHY check makes overall status UNHEALTHY; any DEGRADED makes the aggregate DEGRADED.

### 3.8 Safety Invariants

1. Zero-trust verification — verify every assumption; nothing works until proven.
2. Observability first — if you can't measure it, you can't safely migrate it.
3. Progressive exposure — never expose 100% without intermediate validation.
4. Automated guardrails — human judgment is fallible; automate safety checks.
5. Immutable artifacts — never modify production in place; deploy new versions.
6. Rollback paranoia — always have a tested, working rollback ready.
7. Blameless culture — focus on system safety, not individual blame.

## 4. Rollback Strategies

### 4.1 Rollback Decision Matrix

| Scenario | Detection | Action | Time | Verification |
|---|---|---|---|---|
| Critical error spike | Error budget exhaustion, p99 > threshold | Immediate traffic switch | 1-2 min | Health checks, error < 1% |
| Data corruption | Integrity checks, checksum failures | Stop writes + PITR | 15-30 min | Data consistency verification |
| Security vulnerability | Security scanning, threat detection | Flag disable + rollback | < 1 min | Vulnerability scan clean |
| Performance degradation | Latency SLO breach, throughput drop | Gradual rollback | 5-10 min | Performance benchmarks |
| Partial AZ failure | AZ health checks | Failover healthy AZ | 5-15 min | Cross-AZ health verification |
| Feature-specific issue | Flag metrics, user complaints | Flag disable | < 1 min | Feature functionality test |
| Canary regression | Statistical canary analysis | Canary termination | 2-5 min | Stable deployment metrics |
| Configuration drift | IaC diff | Config re-apply | 3-5 min | Config validation |

Simple reversibility ladder: flag disable (< 1 min) → traffic switch (1-2 min) → deployment rollback (minutes) → data rollback (PITR, slowest — avoid needing it).

### 4.2 Blue-Green Rollback

Switch the service selector back to the healthy color. Gate before switching; verify after.

```bash
# Gate 1: target deployment healthy and fully ready
kubectl rollout status deployment/$SERVICE-$COLOR --timeout=30s
READY=$(kubectl get deployment $SERVICE-$COLOR -o jsonpath='{.status.readyReplicas}')
DESIRED=$(kubectl get deployment $SERVICE-$COLOR -o jsonpath='{.spec.replicas}')
[ "$READY" -lt "$DESIRED" ] && exit 1        # refuse to switch onto a sick color

# Switch traffic
kubectl patch service $SERVICE --type='json' -p='[{
    "op": "replace", "path": "/spec/selector/color", "value": "'$COLOR'"}]'

# Gate 2: health-check loop (5 attempts, 5s apart); failure reverts to the previous color
for i in 1 2 3 4 5; do
    curl -sf http://$SERVICE/health && break
    [ $i -eq 5 ] && kubectl patch service $SERVICE --type='json' -p='[{
        "op": "replace", "path": "/spec/selector/color", "value": "'$PREV'"}]' \
        && alert_on_call   # automatic revert + page
    sleep 5
done

# Post-rollback: watch error rate (>5% => monitor 60s), then log a k8s Event
kubectl create event --reason=BlueGreenRollback \
  --message="Rolled back $PREV -> $COLOR" --involved-object=service/$SERVICE
```

### 4.3 Canary Rollback

```bash
# Rollback criteria (checked before tearing down):
#   canary error rate > 5%  OR  canary p99 > stable p99 + 500ms
kubectl scale deployment $DEPLOY-canary --replicas=0
kubectl wait --for=delete pod -l app=$DEPLOY-canary --timeout=60s
kubectl patch service $DEPLOY -p '{"spec":{"selector":{"version":"stable"}}}'
kubectl rollout status deployment/$DEPLOY-stable --timeout=60s
kubectl create event --reason=CanaryRollback \
  --message="Canary rollback $PCT% -> 0%" --involved-object=deployment/$DEPLOY
```

If metrics are within tolerance, require explicit confirmation before a forced rollback.

### 4.4 Kubernetes Deployment Rollback

```bash
kubectl rollout history deployment/$DEPLOY -n $NS          # list revisions
kubectl rollout undo deployment/$DEPLOY -n $NS            # previous revision
kubectl rollout undo deployment/$DEPLOY -n $NS --to-revision=$REV
kubectl rollout status deployment/$DEPLOY -n $NS --timeout=300s   # on failure: describe pods
# Post-check: curl /health inside the pod, 5 rounds, 2s apart
```

### 4.5 StatefulSet Rollback

StatefulSets have no `rollout undo`; roll back by pinning the previous image. Data compatibility must be verified first — the new release may have migrated data the old image cannot read.

```bash
kubectl get pvc -n $NS -l app=$STATEFULSET           # confirm volumes intact
kubectl set image statefulset/$STS $STS=$STS:$IMAGE_TAG -n $NS
kubectl rollout status statefulset/$STS -n $NS --timeout=600s
for pod in $(kubectl get pods -n $NS -l app=$STS -o name); do
    kubectl wait --for=condition=ready -n $NS $pod --timeout=120s
done
```

### 4.6 Helm Rollback

```bash
helm history $RELEASE -n $NS                  # revisions table
helm rollback $RELEASE -n $NS                 # previous revision
helm rollback $RELEASE $REV -n $NS            # specific revision
helm status $RELEASE -n $NS                   # verify
helm test $RELEASE -n $NS                     # run test hooks; failures => manual check
```

### 4.7 PostgreSQL Point-in-Time Recovery

Destructive: takes a pre-rollback backup of the *current* state first (you may need to re-target), then restores.

```bash
# 0. Pre-rollback backup of current data dir (fast stop, tar)
pg_ctl stop -D $DATA_DIR -m fast
tar czf /tmp/pre-rollback-$(date +%s).tar.gz -C $(dirname $DATA_DIR) $(basename $DATA_DIR)

# 1. Clear and restore base backup
rm -rf $DATA_DIR/* && tar xzf $BACKUP_DIR/latest.tar.gz -C $DATA_DIR

# 2. Configure PITR
cat > $DATA_DIR/postgresql.auto.conf <<EOF
restore_command = 'cp $WAL_DIR/%f %p'
recovery_target_time = '$TARGET_TIME'
recovery_target_action = 'pause'
recovery_target_inclusive = true
EOF
touch $DATA_DIR/recovery.signal

# 3. Start and monitor; pause lets you verify before promoting
pg_ctl start -D $DATA_DIR -l $DATA_DIR/log/recovery.log
# watch pg_is_in_recovery() and pg_last_wal_receive_lsn() until replay completes

# 4. Promote and verify writability
pg_ctl promote -D $DATA_DIR
psql -c 'CREATE TABLE __rollback_test (id int); DROP TABLE __rollback_test;'
```

Target confirmed via `pg_last_xact_replay_timestamp()`. Keep a typed confirmation prompt in the runbook (`CONFIRM`) — the restore destroys current data.

### 4.8 MySQL Replication Failover (GTID)

```bash
# Gate: replica lag must be tolerable
mysql -h $NEW_MASTER -e "SHOW SLAVE STATUS\G" | grep Seconds_Behind_Master

# Failover sequence
mysql -e "FLUSH TABLES WITH READ LOCK; SET GLOBAL read_only = ON;"    # stop writes (old)
MASTER_POS=$(mysql -e "SHOW MASTER STATUS\G")                        # capture position
mysql -h $NEW_MASTER -e "SELECT MASTER_POS_WAIT('$MASTER_POS');"    # let it catch up
mysql -h $NEW_MASTER -e "STOP SLAVE; RESET SLAVE ALL;"               # detach from old master
mysql -h $NEW_MASTER -e "SET GLOBAL read_only = OFF; UNLOCK TABLES;"
# Re-point clients (DNS/service discovery)
mysql -e "CHANGE MASTER TO MASTER_HOST='$NEW_MASTER', MASTER_AUTO_POSITION=1; START SLAVE;"  # old -> replica
```

### 4.9 AWS ECS Rollback

```bash
aws ecs describe-services --cluster $CLUSTER --services $SVC \
    --query 'services[0].deployments[?status==`ACTIVE`].taskDefinition' --output text
aws ecs update-service --cluster $CLUSTER --service $SVC \
    --task-definition $PREVIOUS_TASK_DEF --force-new-deployment
aws ecs wait services-stable --cluster $CLUSTER --services $SVC
aws ecs describe-tasks --cluster $CLUSTER --tasks $TASK --query 'tasks[0].healthStatus'
```

Refuse the rollback if no previous ACTIVE task definition exists — current deploy stays and the error escalates.

### 4.10 Azure App Service Rollback

```powershell
# Production: redeploy previous deployment
az webapp deployment list --resource-group $RG --name $APP
az webapp deployment restore --resource-group $RG --name $APP --deployment-id $PREV.id
# Deployment slots: swap back instead
az webapp deployment slot swap --resource-group $RG --name $APP --slot $TARGET --target-slot $Slot
az webapp show --resource-group $RG --name $APP --query state   # verify Running
```

### 4.11 GCP Cloud Run Rollback

```bash
gcloud run revisions list --service $SVC --region $R          # find previous revision
CURRENT=$(gcloud run services describe $SVC --region $R \
    --format='value(spec.template.metadata.name)')
HEALTH=$(gcloud run revisions describe $PREV --region $R \
    --format='value(status.conditions[0].status)')            # require True before switching
gcloud run services update-traffic $SVC --to-revisions=$PREV=100 --region $R
gcloud run services describe $SVC --region $R --format='value(status.conditions[0].status)'
```

Unhealthy previous revision = escalate; switching traffic to a sick revision doubles the outage.

### 4.12 Feature Flag Emergency Rollback

Sequence: snapshot current flag state (audit) → disable flag → invalidate CDN/app caches → page on-call → wait ~2s propagation → verify the flag actually evaluates off.

Multi-flag rollback: disable all in sequence without per-flag verification, then verify the batch after ~5s propagation; continue on individual failures and re-attempt failed keys.

### 4.13 Automated Rollback Thresholds

Default trigger config: error rate > 5%, p99 > 2000ms, p95 > 1000ms, business metric < 90% of baseline, cooldown 30 min between rollbacks, ML predictive risk > 0.8 preempts. Feature-name present → flag rollback; otherwise full deployment rollback. Every automated rollback writes an audit record (triggers, duration, verification result, timestamp).

### 4.14 Testing Rollbacks (Chaos Drills)

Run rollback procedures in staging monthly; cover at minimum:

- Blue-green reversibility — switch color, assert health, switch back, assert health.
- Canary auto-rollback — start canary at 10%, inject errors, assert automatic termination to 0%.
- Database PITR — record timestamp, write data, roll back to timestamp, assert data loss < 5s and test data gone.

### 4.15 Rollback Best Practices and TTR Goals

1. Automated detection — trigger rollbacks via metric/ML anomaly detection before humans notice.
2. Graduated rollback — 100% → 50% → 0% for gradual degradation.
3. Rollback drills — monthly chaos exercises that specifically test rollback.
4. TTR goals: critical errors < 2 min, performance degradation < 5 min, data corruption < 15 min.
5. Track: mean time to detect (MTTD), mean time to rollback (MTTR), false-positive rate, rollback success rate.
6. Post-rollback analysis — mandatory post-mortem within 24 hours.
7. Immutable infrastructure — consistent, redeployable rollback targets.

## 5. Breaking Changes by Technology

### 5.1 Python 3.11 → 3.12

**distutils removed (PEP 632).** Replace with `setuptools` or a modern build backend:

```python
# Before                      # After
from distutils.core import setup        from setuptools import setup, Extension
from distutils.extension import Extension

# Preferred: pyproject.toml
# [build-system] requires = ["hatchling"], build-backend = "hatchling.build"
```

**PEP 695 type parameter syntax:**

```python
# Before                                  # After (3.12)
T = TypeVar('T'); P = ParamSpec('P')       class Container[T]:
class Container(Generic[T]): ...              def get_item(self) -> T: ...
Vector: TypeAlias = list[float]            type Vector = list[float]
                                           type IntFunc[**P] = Callable[P, int]
```

**PEP 701 f-strings** — any valid expression inside: quote reuse, multi-line with comments, backslashes, arbitrary nesting (`f"{f"{f"{1+1}"}"}"`).

**PEP 709 comprehension inlining** — comprehensions no longer create a scope frame: `[k for k in locals()]` may raise `RuntimeError` under tracing; snapshot first (`keys = list(locals())`). Tracebacks lose the separate comprehension frame.

**PEP 684 per-interpreter GIL** — C-API only in 3.12 (`Py_NewInterpreterFromConfig` with `PyInterpreterConfig_OWN_GIL`); Python-level API expected in 3.13.

**Modules removed:** `asynchat`, `asyncore` → `asyncio`; `imp` → `importlib`; `smtpd` → `aiosmtpd`. Various `unittest.TestCase` method aliases also removed.

Tools: `pyupgrade --py312-plus`, `python-modernize -w`, `mypy>=1.6.0` (PEP 695 support) with `--python-version 3.12`, `ruff check --target-version py312`.

### 5.2 Node.js 18 → 20

**Permission model (experimental):** restrict fs/child-process/worker access explicitly.

```bash
node --experimental-permission --allow-fs-read=* --allow-fs-write=/tmp app.js
# runtime check: process.permission.has('fs.read', '/path')
```

**ESM loader hooks now run in a dedicated thread** (`node --experimental-loader=./loader.mjs`); `import.meta.resolve()` is synchronous.

**V8 11.3:** `String.prototype.isWellFormed()/toWellFormed()`, change-by-copy arrays (`toSorted`, `toReversed`, `with`), resizable `ArrayBuffer` / growable `SharedArrayBuffer`, RegExp `v` flag (set notation: `/[\p{Letter}&&[^\p{ASCII}]]/v`).

**WASI constructor requires `version`** (`version: 'preview1'`) — no default.

**Test runner stable:** `node --test app.test.js`, `import { test } from 'node:test'`; watch mode `--test --watch`; coverage `--experimental-test-coverage`.

**Deprecations tightening:** `url.parse()` with invalid ports warns (will throw) — migrate to `new URL()`; `process.exit(<non-numeric>)` throws `TypeError` — always pass numeric codes.

Tools: `check-node-version --node ">=20"`, `npm audit fix`, `corepack enable` for consistent package-manager versions.

### 5.3 Java 17 → 21 (LTS)

**Pattern matching for switch (JEP 441, final):** type patterns in cases, `when` guards, `null` handling, qualified enum constants; replaces `instanceof` chains.

```java
return switch (obj) {
    case Integer i -> String.format("int %d", i);
    case String s  -> "String " + s;
    case null      -> "null";
    default        -> obj.toString();
};
```

**Virtual threads (JEP 444):** `Executors.newVirtualThreadPerTaskExecutor()` or `Thread.startVirtualThread(r)`. Rules:
- Never pool virtual threads (`newFixedThreadPool` is for platform threads only).
- Pinning: avoid `synchronized` around blocking I/O inside virtual threads — use `ReentrantLock` so the carrier frees. Detect with `-Djdk.tracePinnedThreads=full` and the JFR `jdk.VirtualThreadPinned` event.

**Record patterns (JEP 440):** `obj instanceof Point(int x, int y)` and nested deconstruction in switch.

**Sequenced collections (JEP 431):** `addFirst/addLast/getFirst/getLast/reversed` on `List`/`LinkedHashMap`/`TreeMap` etc.

**String templates (JEP 430, preview):** `STR."My name is \{name}"` — requires `--enable-preview`; custom processors possible.

**KEM API (JEP 452):** `KeyEncapsulationMechanism` for post-quantum key exchange.

Runtime feature detection: reflective `Thread.class.getMethod("isVirtual")` or `Runtime.version().feature() >= 21` before using new APIs.

### 5.4 Spring Boot 2.x → 3.x

- Requires Java 17+ (was 11).
- Jakarta EE: `javax.*` → `jakarta.*` across all imports (`jakarta.persistence.Entity`, `jakarta.validation.constraints.NotNull`).
- Configuration properties and GraalVM native-image behavior changes.
- Automated fix: OpenRewrite recipe `org.openrewrite.java.spring.boot3.UpgradeSpringBoot_3_2` via the rewrite-maven-plugin; `mvn versions:use-latest-versions` for plain upgrades.

### 5.5 Express.js 4 → 5

- Error middleware must take **4** arguments or it is not an error handler: `function(err, req, res, next)`.
- `req.param()` removed.
- `res.send(number)` semantics changed — send statuses explicitly.

```javascript
app.use(function(err, req, res, next) { res.status(500).send(err.message); });
```

### 5.6 React 17 → 18

- `ReactDOM.render` → `createRoot` from `react-dom/client`.
- Automatic batching by default; Strict Mode double-invocation changes.

```javascript
import { createRoot } from 'react-dom/client';
createRoot(document.getElementById('root')).render(<App />);
```

### 5.7 Django 3.x → 4.x → 5.x

- `django.conf.urls.url()` removed → `re_path()` / `path()`.
- `ugettext()` removed → `gettext()`.
- `CSRF_COOKIE_MASKED` setting removed.
- Django 5.0: db-generated columns, streamlined password validators.

```python
# url(r'^api/', include('api.urls'))   ->   re_path(r'^api/', include('api.urls'))
# ugettext('Hello')                    ->   gettext('Hello')
```

### 5.8 Flask 1.x → 2.x → 3.x

- JSON encoder/decoder moved to `app.json` (`JSONProvider`).

```python
class CustomJSONProvider(app.json.JSONProvider): ...
app.json = CustomJSONProvider(app)
```

- 3.x removes `app.before_first_request`; CLI changes across all versions.

### 5.9 PostgreSQL 14 → 15 → 16

- 15: `jsonb` subscription with NULLs behaves differently — add explicit handling (`COALESCE(jsonb_column -> 'key', 'null'::jsonb)`).
- 16: SQL/JSON standard support, `JSON_OBJECT()` constructor; optimizer statistics changes (re-benchmark queries).

### 5.10 MongoDB 4.x → 5.x → 7.x

- 5.0: deprecated operators removed, aggregation changes.
- 6.0: legacy API support removed.
- 7.0: Atlas Search and time-series enhancements.

### 5.11 Kubernetes 1.24 → 1.28+

- Dockershim removed (1.24) — containerd/cri-o required.
- PodSecurityPolicy removed (1.25) → Pod Security Admission via namespace labels.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

- Beta API removals each release; Gateway API v1 graduated.

### 5.12 Terraform 1.0 → 1.6+

- Lock file (`.terraform.lock.hcl`) requirements; `plan` output format changes; `terraform test` (1.5, experimental).
- 1.6: `import` blocks generate configuration:

```hcl
import { to = aws_instance.example, id = "i-1234567890abcdef0" }
```

### 5.13 API Breaking Changes

| Change type | Severity | Example |
|---|---|---|
| Field removal | Critical | `user.email` removed without notice |
| Endpoint removal | Critical | `/v1/users` removed |
| Authentication change | Critical | API key moved header → query param |
| Type change | High | `user.id` int → string |
| Format change | High | ISO 8601 → Unix timestamp |
| Behavior change | High | POST returns 201 instead of 200 |
| Default value change | Medium | Pagination default 100 → 10 |
| Rate limiting change | Medium | 1000 → 100 req/min |

Versioning strategies: URL path (`/api/v2/users`), header (`Accept: application/vnd.api+json;version=2`), content negotiation (`application/vnd.myapi.v2+json`).

Communication rules: `Sunset` and `Deprecation` headers; published support lifecycle; migration guides; compatibility layers serving both versions during transition; scheduled breaking-change windows.

### 5.14 Breaking Change Severity Matrix

| Severity | Definition | API example | Dependency example |
|---|---|---|---|
| Critical | Application won't start | Removed required function | Removed required class |
| High | Feature broken, data-loss risk | Response format changed | Default behavior changed |
| Medium | Behavior changed, workaround exists | Default value changed | Deprecated feature removed |
| Low | Warnings, cosmetic | Deprecation notices | Documentation updates |

### 5.15 Detection Strategies

Static analysis:

```bash
pyupgrade --py311-plus '**/*.py'                      # Python syntax modernization
npx jscodeshift -t transforms/ api-migration.js        # JS/TS AST transforms
mvn rewrite:run -Drewrite.recipeArtifactCoordinates=org.openrewrite.recipe:rewrite-spring:LATEST
mypy --strict --warn-return-any --warn-unreachable   # API compat
```

Runtime detection:

```python
warnings.filterwarnings('default', category=DeprecationWarning)
warnings.filterwarnings('error', category=FutureWarning)   # fail hard on future warnings
```

```javascript
process.on('warning', (w) => console.warn(w.name, w.message)); // Node deprecations
```

Contract testing (Pact) pins consumer/provider expectations before a provider change ships breaking shapes:

```python
(pact.given('user exists').upon_receiving('a request for user')
 .with_request('GET', '/api/v2/users/1')
 .will_respond_with(200, body={'id': 1, 'name': 'Test User'}))
```

## 6. Cross-Cutting Migration Best Practices

1. Start with written outcomes; identify seams early; accept transitional architecture as deliberate, disposable scaffolding.
2. Organizational processes age systems as much as code does — change the process or the migration reverts.
3. Cohort-based routing keeps sessions consistent across old/new implementations.
4. Run old and new in parallel (shadow/parallel-run) before and during exposure.
5. Feature flags give rollback capability that survives a deploy; every flag needs an owner and an expiry.
6. Monitor business metrics (conversion, engagement), not just error rates and latency.
7. Establish performance baselines before migrating; re-benchmark after.
8. Practice rollbacks in staging before you need them in production.
9. Immutable artifacts make rollback targets consistent; never patch production in place.
10. For JVM migrations monitor heap/GC and virtual-thread metrics; for all migrations, watch module count, cycle count, and dependency debt.

## 7. References

- Martin Fowler — Strangler Fig (Aug 2024): <https://martinfowler.com/bliki/StranglerFigApplication.html>
- Martin Fowler — Patterns of Legacy Displacement: <https://martinfowler.com/articles/patterns-legacy-displacement/>
- Martin Fowler — Feature Toggles: <https://martinfowler.com/articles/feature-toggles.html>
- Martin Fowler — Circuit Breaker: <https://martinfowler.com/bliki/CircuitBreaker.html>
- Martin Fowler — Blue-Green Deployment: <https://martinfowler.com/bliki/BlueGreenDeployment.html>
- Martin Fowler — Canary Release: <https://martinfowler.com/bliki/CanaryRelease.html>
- Thoughtworks — Embracing Strangler Fig: <https://www.thoughtworks.com/insights/articles/embracing-strangler-fig-pattern-legacy-modernization-part-one>
- Google SRE — Error Budgets: <https://sre.google/sre-book/embracing-risk/>
- AWS Well-Architected — Reliability: <https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html>
- Python 3.12 What's New: <https://docs.python.org/3/whatsnew/3.12.html>
- PEP 695 Type Parameter Syntax: <https://peps.python.org/pep-0695/>
- PEP 701 f-strings: <https://peps.python.org/pep-0701/>; PEP 709 Comprehension Inlining: <https://peps.python.org/pep-0709/>
- Node.js 20 Release: <https://nodejs.org/en/blog/release/v20.0.0>; Permission Model: <https://nodejs.org/api/permissions.html>
- Java 21: <https://openjdk.org/projects/jdk/21/>; JEP 441: <https://openjdk.org/jeps/441>; JEP 444: <https://openjdk.org/jeps/444>; JEP 440: <https://openjdk.org/jeps/440>; JEP 431: <https://openjdk.org/jeps/431>
- Kubernetes Deployment Rollback: <https://kubernetes.io/docs/concepts/workloads/controllers/deployment/>
- AWS ECS Deployments: <https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployments.html>
- Cloud Run Revisions: <https://cloud.google.com/run/docs/managing/revisions>
- Azure Chaos Studio: <https://azure.microsoft.com/en-us/services/chaos-studio/>
- NetworkX: <https://networkx.org/documentation/stable/>
- Martin Fowler — Isolation vs Healthy Dependencies: <https://martinfowler.com/articles/isolation-versus-healthy-dependencies.html>
- Snyk — Dependency Management: <https://snyk.io/learn/dependency-management/>
