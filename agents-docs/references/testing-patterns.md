# Testing Strategy Patterns

---

# Load Testing Scenarios

Pre-built load test scenarios for common use cases.

## Overview

This guide provides ready-to-use load testing scenarios for various application types and architectures. Updated with k6 v1.7.x (2026) best practices including browser testing, distributed execution, and AI-assisted test authoring.

## Latest k6 Features (v1.7.x - 2026)

### Key Updates

- **k6 Studio**: Visual test builder for creating tests without coding
- **Browser Module**: Full Playwright-compatible browser testing (v0.52+)
- **AI Assistant Integration**: MCP clients for AI-assisted test authoring
- **Distributed Testing**: Enhanced k6 Operator for Kubernetes
- **Experimental Modules**: CSV parser, file system, streams API
- **gRPC Testing**: Native protocol support with streaming

### Installation

```bash
# macOS
brew install k6

# Linux
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg \
  --keyserver hkp://keyserver.ubuntu.com:80 \
  --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | \
  sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6

# Docker
docker pull grafana/k6:latest
```

## API Load Testing

### REST API Scenario (2026 Best Practices)

```javascript
// k6-rest-api.js
import http from 'k6/http';
import { check, sleep, group } from 'k6';

// Scenario-based configuration (recommended in 2026)
export const options = {
  scenarios: {
    // Different user behaviors
    browse: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m', target: 100 },   // Ramp up
        { duration: '5m', target: 100 },   // Steady state
        { duration: '2m', target: 200 },    // Increase load
        { duration: '5m', target: 200 },   // Steady state
        { duration: '2m', target: 0 },     // Ramp down
      ],
      gracefulRampDown: '30s',
    },
    // Arrival-rate based (more realistic for APIs)
    api_requests: {
      executor: 'ramping-arrival-rate',
      startRate: 50,
      timeUnit: '1s',
      preAllocatedVUs: 50,
      maxVUs: 200,
      stages: [
        { duration: '2m', target: 100 },    // 100 req/s
        { duration: '5m', target: 100 },
        { duration: '2m', target: 200 },    // 200 req/s
        { duration: '5m', target: 200 },
      ],
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<500'],     // 95% under 500ms
    http_req_duration: ['p(99)<1000'],    // 99% under 1s
    http_req_failed: ['rate<0.01'],      // Error rate < 1%
    'http_req_duration{scenario:api_requests}': ['p(95)<300'], // Per-scenario
  },
  // Cloud output configuration
  ext: {
    loadimpact: {
      distribution: {
        'amazon:us:ashburn': { loadZone: 'amazon:us:ashburn', percent: 50 },
        'amazon:de:frankfurt': { loadZone: 'amazon:de:frankfurt', percent: 50 },
      },
    },
  },
};

const BASE_URL = __ENV.BASE_URL || 'https://api.example.com';

export function browse() {
  group('Browse Flow', () => {
    // GET request with tags for filtering
    const getRes = http.get(`${BASE_URL}/api/users`, {
      tags: { name: 'users_list', type: 'read' },
    });

    check(getRes, {
      'GET status is 200': (r) => r.status === 200,
      'GET response time < 500ms': (r) => r.timings.duration < 500,
      'content-type is json': (r) => r.headers['Content-Type'].includes('application/json'),
    });

    sleep(Math.random() * 3 + 1); // Think time: 1-4 seconds
  });
}

export function api_requests() {
  group('API Operations', () => {
    // POST request with payload
    const payload = JSON.stringify({
      name: `User_${__VU}_${__ITER}`,
      email: `user${__VU}_${__ITER}@test.com`,
      timestamp: new Date().toISOString(),
    });

    const postRes = http.post(`${BASE_URL}/api/users`, payload, {
      headers: {
        'Content-Type': 'application/json',
        'X-Request-ID': `req-${__VU}-${__ITER}`,
      },
      tags: { name: 'users_create', type: 'write' },
    });

    check(postRes, {
      'POST status is 201': (r) => r.status === 201,
      'POST response time < 800ms': (r) => r.timings.duration < 800,
      'has user id': (r) => JSON.parse(r.body).id !== undefined,
    });

    sleep(0.5);
  });
}
```

### GraphQL Scenario with Subscriptions

```javascript
// k6-graphql-advanced.js
import http from 'k6/http';
import ws from 'k6/ws';  // WebSocket module for subscriptions
import { check } from 'k6';

export const options = {
  vus: 50,
  duration: '10m',
  thresholds: {
    http_req_duration: ['p(95)<300'],
    ws_connecting_duration: ['p(95)<500'], // WebSocket connection time
  },
};

const query = `
  query GetUserWithPosts($id: ID!, $limit: Int = 10) {
    user(id: $id) {
      id
      name
      email
      posts(limit: $limit) {
        title
        content
        createdAt
        comments {
          author
          text
        }
      }
    }
  }
`;

const subscription = `
  subscription OnUserActivity($userId: ID!) {
    userActivity(userId: $userId) {
      type
      timestamp
      metadata
    }
  }
`;

// HTTP GraphQL query
export function graphqlQuery() {
  const res = http.post(
    'https://api.example.com/graphql',
    JSON.stringify({
      query: query,
      variables: {
        id: Math.floor(Math.random() * 10000) + 1,
        limit: Math.floor(Math.random() * 20) + 5,
      },
      operationName: 'GetUserWithPosts',
    }),
    {
      headers: {
        'Content-Type': 'application/json',
      },
      tags: { type: 'graphql_query' },
    }
  );

  check(res, {
    'status is 200': (r) => r.status === 200,
    'no GraphQL errors': (r) => {
      const body = JSON.parse(r.body);
      return !body.errors;
    },
    'response time < 300ms': (r) => r.timings.duration < 300,
    'has data': (r) => {
      const body = JSON.parse(r.body);
      return body.data && body.data.user;
    },
  });
}

// WebSocket subscription test
export function graphqlSubscription() {
  const url = 'wss://api.example.com/graphql';
  const userId = Math.floor(Math.random() * 1000) + 1;

  const res = ws.connect(url, {}, function(socket) {
    socket.on('open', () => {
      // Send subscription request
      socket.send(JSON.stringify({
        type: 'subscribe',
        id: `sub-${__VU}-${__ITER}`,
        payload: {
          query: subscription,
          variables: { userId },
        },
      }));
    });

    socket.on('message', (msg) => {
      const data = JSON.parse(msg);
      check(data, {
        'received data': (d) => d.type === 'data',
        'has payload': (d) => d.payload !== undefined,
      });
    });

    socket.on('close', () => {
      console.log(`Subscription closed for user ${userId}`);
    });

    // Close after 30 seconds
    socket.setTimeout(() => {
      socket.close();
    }, 30000);
  });

  check(res, {
    'WebSocket connected': (r) => r && r.status === 101,
    'connected in < 500ms': (r) => r.timings.duration < 500,
  });
}
```

## Browser Testing with k6 (2026)

### Hybrid Performance Testing

```javascript
// k6-browser-hybrid.js
import { browser } from 'k6/experimental/browser';  // v0.52+
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    // Browser-based testing for Core Web Vitals
    browser_test: {
      executor: 'shared-iterations',
      vus: 5,
      iterations: 10,
      options: {
        browser: {
          type: 'chromium',
        },
      },
    },
    // API load test
    api_test: {
      executor: 'constant-vus',
      vus: 50,
      duration: '5m',
      startTime: '30s',  // Start after browser test begins
    },
  },
  thresholds: {
    // Core Web Vitals thresholds (2026 standards)
    'browser_web_vital_lcp': ['p(75)<2500'],  // Largest Contentful Paint < 2.5s
    'browser_web_vital_fid': ['p(75)<100'],    // First Input Delay < 100ms
    'browser_web_vital_cls': ['p(75)<0.1'],    // Cumulative Layout Shift < 0.1
    'browser_web_vital_inp': ['p(75)<200'],    // Interaction to Next Paint < 200ms
    http_req_duration: ['p(95)<500'],
  },
};

export async function browser_test() {
  const context = browser.newContext();
  const page = context.newPage();

  try {
    // Navigate and measure
    await page.goto('https://example.com/login', {
      waitUntil: 'networkidle',
    });

    // Fill form using Playwright-compatible API
    await page.locator('input[name="username"]').fill(`user${__VU}`);
    await page.locator('input[name="password"]').fill('password123');

    // Click and wait for navigation
    const [response] = await Promise.all([
      page.waitForNavigation(),
      page.locator('button[type="submit"]').click(),
    ]);

    check(response, {
      'login successful': (r) => r.status() === 200,
      'redirected to dashboard': () => page.url().includes('/dashboard'),
    });

    // Measure specific user interactions
    await page.locator('[data-testid="load-data"]').click();
    await page.waitForSelector('[data-testid="data-loaded"]');

    // Take screenshot for debugging
    await page.screenshot({ path: `screenshots/test-${__VU}-${__ITER}.png` });

  } finally {
    await page.close();
    await context.close();
  }
}

export function api_test() {
  // Background API load while browser tests run
  const res = http.get('https://api.example.com/data');

  check(res, {
    'api status is 200': (r) => r.status === 200,
    'api response fast': (r) => r.timings.duration < 300,
  });
}
```

### E-commerce Checkout Flow with Browser

```javascript
// k6-ecommerce-browser.js
import { browser } from 'k6/experimental/browser';
import { check, sleep, group } from 'k6';

export const options = {
  scenarios: {
    browse: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 50 },
        { duration: '3m', target: 50 },
        { duration: '1m', target: 0 },
      ],
      options: {
        browser: {
          type: 'chromium',
        },
      },
    },
    checkout: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 10 },
        { duration: '3m', target: 10 },
        { duration: '1m', target: 0 },
      ],
      options: {
        browser: {
          type: 'chromium',
        },
      },
    },
  },
};

export async function browse() {
  const context = browser.newContext();
  const page = context.newPage();

  try {
    await group('Browse Products', async () => {
      await page.goto('https://shop.example.com/products');

      check(page, {
        'products page loaded': (p) => p.locator('.product-list').isVisible(),
        'no errors': (p) => !p.locator('.error-message').isVisible(),
      });

      // Simulate realistic browsing
      await page.locator('.product-card').first().click();
      sleep(Math.random() * 3 + 1);

      // Scroll and interact
      await page.evaluate(() => window.scrollBy(0, 500));
      sleep(Math.random() * 2 + 0.5);
    });

  } finally {
    await page.close();
    await context.close();
  }
}

export async function checkout() {
  const context = browser.newContext();
  const page = context.newPage();

  try {
    await group('Full Checkout Flow', async () => {
      // Add to cart
      await page.goto(`https://shop.example.com/products/${Math.floor(Math.random() * 100)}`);
      await page.locator('button[data-testid="add-to-cart"]').click();
      await page.waitForSelector('.cart-count');

      // Go to cart
      await page.goto('https://shop.example.com/cart');
      check(page, {
        'cart has items': (p) => p.locator('.cart-item').count() > 0,
      });

      // Proceed to checkout
      await page.locator('button[data-testid="checkout"]').click();

      // Fill shipping info
      await page.locator('input[name="name"]').fill('Test User');
      await page.locator('input[name="address"]').fill('123 Test St');
      await page.locator('input[name="city"]').fill('Test City');

      // Simulate payment
      await page.locator('button[data-testid="place-order"]').click();

      // Wait for confirmation
      await page.waitForSelector('.order-confirmation', { timeout: 10000 });

      check(page, {
        'order confirmed': (p) => p.locator('.order-confirmation').isVisible(),
        'has order number': (p) => p.locator('.order-number').textContent().length > 0,
      });
    });

  } finally {
    await page.close();
    await context.close();
  }
}
```

## WebSocket Testing

### Real-time Chat with Reconnection

```javascript
// k6-websocket-advanced.js
import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { Counter, Trend } from 'k6/metrics';

// Custom metrics
const reconnections = new Counter('websocket_reconnections');
const messageLatency = new Trend('message_latency');

export const options = {
  vus: 100,
  duration: '10m',
  thresholds: {
    'message_latency': ['p(95)<500'],  // Message latency under 500ms
    'websocket_reconnections': ['count<10'],  // Max 10 reconnections
  },
};

export default function() {
  const url = 'wss://chat.example.com/ws';
  const roomId = `room-${Math.floor(__VU / 10)}`;  // Group users into rooms
  let messageCount = 0;
  let reconnectCount = 0;

  const connect = () => {
    const res = ws.connect(url, {
      headers: {
        'X-User-ID': `user-${__VU}`,
      },
    }, function(socket) {
      let connected = false;
      let pingInterval;

      socket.on('open', () => {
        connected = true;

        // Join room
        socket.send(JSON.stringify({
          type: 'join',
          room: roomId,
          user: `user-${__VU}`,
        }));

        // Send heartbeat
        pingInterval = socket.setInterval(() => {
          socket.send(JSON.stringify({ type: 'ping', timestamp: Date.now() }));
        }, 30000);
      });

      socket.on('message', (msg) => {
        const data = JSON.parse(msg);

        check(data, {
          'valid message format': (d) => d.type !== undefined,
        });

        if (data.type === 'message') {
          messageCount++;
          // Calculate latency if timestamp included
          if (data.timestamp) {
            const latency = Date.now() - data.timestamp;
            messageLatency.add(latency);
          }
        }

        if (data.type === 'pong') {
          // Heartbeat response
        }
      });

      socket.on('close', (code, reason) => {
        connected = false;
        if (pingInterval) clearInterval(pingInterval);

        check(null, {
          'clean disconnect': () => code === 1000,
        });
      });

      socket.on('error', (e) => {
        console.error(`WebSocket error for user ${__VU}:`, e.error());
      });

      // Send messages periodically
      const messageInterval = socket.setInterval(() => {
        if (connected) {
          socket.send(JSON.stringify({
            type: 'message',
            room: roomId,
            text: `Test message ${messageCount} from user ${__VU}`,
            timestamp: Date.now(),
          }));
        }
      }, 5000);

      // Close after duration
      socket.setTimeout(() => {
        clearInterval(messageInterval);
        socket.close();
      }, 300000);  // 5 minutes
    });

    return res;
  };

  // Initial connection
  let res = connect();

  check(res, {
    'WebSocket connected': (r) => r && r.status === 101,
  });

  // Reconnection logic (simulating network issues)
  sleep(60);
  if (Math.random() < 0.1) {  // 10% chance of reconnection
    reconnectCount++;
    reconnections.add(1);
    sleep(5);
    res = connect();
  }
}
```

## gRPC Load Testing

### gRPC Streaming Scenario

```javascript
// k6-grpc.js
import grpc from 'k6/net/grpc';
import { check, sleep } from 'k6';

const client = new grpc.Client();
client.load(['./protos'], 'service.proto');

export const options = {
  vus: 50,
  duration: '5m',
  thresholds: {
    grpc_req_duration: ['p(95)<300'],
    grpc_streams: ['count>100'],
  },
};

export default function() {
  client.connect('grpc.example.com:443', {
    plaintext: false,
    timeout: '10s',
  });

  // Unary call
  const response = client.invoke('myPackage.MyService/MyMethod', {
    id: __VU,
    message: `Request from VU ${__VU}, iteration ${__ITER}`,
  });

  check(response, {
    'status is OK': (r) => r && r.status === grpc.StatusOK,
    'has response': (r) => r && r.message !== undefined,
    'response time < 300ms': (r) => r && r.timings.duration < 300,
  });

  // Streaming call
  const stream = client.openStream('myPackage.MyService/MyStreamingMethod', {
    id: __VU,
  });

  stream.on('data', (data) => {
    check(data, {
      'stream data received': (d) => d !== undefined,
    });
  });

  stream.on('error', (error) => {
    console.error('Stream error:', error);
  });

  // Send multiple messages
  for (let i = 0; i < 10; i++) {
    stream.write({
      sequence: i,
      payload: `Message ${i}`,
    });
    sleep(0.1);
  }

  stream.close();
  client.close();
  sleep(1);
}
```

## Database Load Testing

### PostgreSQL with Connection Pooling

```python
# locust-postgres-advanced.py
from locust import User, task, between, events
import psycopg2
import psycopg2.pool
import random
import time
from contextlib import contextmanager

class PostgresUser(User):
    wait_time = between(0.1, 2)

    def __init__(self, environment):
        super().__init__(environment)
        self.db_pool = None

    def on_start(self):
        # Initialize connection pool per user
        self.db_pool = psycopg2.pool.ThreadedConnectionPool(
            minconn=1,
            maxconn=5,
            host='localhost',
            database='testdb',
            user='testuser',
            password='testpass',
            port=5432,
            connect_timeout=10,
        )

    def on_stop(self):
        if self.db_pool:
            self.db_pool.closeall()

    @contextmanager
    def get_connection(self):
        conn = None
        try:
            conn = self.db_pool.getconn()
            yield conn
        finally:
            if conn:
                self.db_pool.putconn(conn)

    @task(10)
    def read_user_with_cache(self):
        """Simulate read-heavy workload with caching pattern"""
        user_id = random.randint(1, 10000)

        with self.get_connection() as conn:
            with conn.cursor() as cur:
                start = time.time()
                cur.execute(
                    """
                    SELECT u.*, p.title, p.content
                    FROM users u
                    LEFT JOIN posts p ON p.user_id = u.id
                    WHERE u.id = %s
                    LIMIT 5
                    """,
                    (user_id,)
                )
                results = cur.fetchall()
                duration = (time.time() - start) * 1000

                if duration > 500:
                    self.environment.events.request.fire(
                        request_type="DB",
                        name="slow_query",
                        response_time=duration,
                        response_length=0,
                        context=None,
                        exception=None,
                    )

                assert len(results) >= 0  # At least don't error

    @task(5)
    def write_transaction(self):
        """Simulate write workload with transactions"""
        with self.get_connection() as conn:
            try:
                with conn.cursor() as cur:
                    # Start transaction
                    cur.execute("BEGIN")

                    # Insert order
                    cur.execute("""
                        INSERT INTO orders (user_id, product_id, quantity, status)
                        VALUES (%s, %s, %s, 'pending')
                        RETURNING id
                    """, (
                        random.randint(1, 1000),
                        random.randint(1, 100),
                        random.randint(1, 5)
                    ))
                    order_id = cur.fetchone()[0]

                    # Update inventory
                    cur.execute("""
                        UPDATE inventory
                        SET quantity = quantity - %s
                        WHERE product_id = %s
                    """, (random.randint(1, 5), random.randint(1, 100)))

                    # Commit
                    conn.commit()

            except Exception as e:
                conn.rollback()
                raise

    @task(3)
    def complex_query(self):
        """Simulate complex analytical query"""
        with self.get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT
                        u.id,
                        u.name,
                        COUNT(o.id) as order_count,
                        SUM(o.total) as total_spent,
                        AVG(o.total) as avg_order_value
                    FROM users u
                    LEFT JOIN orders o ON o.user_id = u.id
                    WHERE u.created_at > NOW() - INTERVAL '30 days'
                    GROUP BY u.id, u.name
                    HAVING COUNT(o.id) > 0
                    ORDER BY total_spent DESC
                    LIMIT 100
                """)
                results = cur.fetchall()
                assert len(results) >= 0
```

## Spike and Stress Testing

### Sudden Traffic Spike

```javascript
// k6-spike.js
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    spike: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m', target: 100 },    // Normal load
        { duration: '10s', target: 5000 },   // Sudden massive spike
        { duration: '3m', target: 5000 },    // Sustained high load
        { duration: '30s', target: 100 },    // Quick recovery
        { duration: '2m', target: 100 },      // Verify stability
        { duration: '30s', target: 0 },      // Ramp down
      ],
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    http_req_duration: ['p(99)<3000'],  // 99th percentile under 3s even during spike
    http_req_failed: ['rate<0.05'],      // Error rate < 5% during spike
  },
};

export default function() {
  const res = http.get('https://api.example.com/health', {
    tags: { type: 'health_check' },
  });

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 3s': (r) => r.timings.duration < 3000,
    'no error response': (r) => !r.body.includes('error'),
  });
}
```

### Soak Testing (Long-duration Stability)

```javascript
// k6-soak.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend, Rate } from 'k6/metrics';

// Custom metrics for memory leak detection
const memoryUsage = new Trend('memory_usage_mb');
const errorRate = new Rate('custom_errors');

export const options = {
  stages: [
    { duration: '5m', target: 100 },     // Ramp up
    { duration: '8h', target: 100 },      // Stay at 100 for 8 hours
    { duration: '5m', target: 0 },       // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.001'],       // Very low error rate
    custom_errors: ['rate<0.01'],
  },
};

export default function() {
  const startTime = Date.now();

  // Multiple endpoints to exercise full application
  const endpoints = [
    '/api/users',
    '/api/products',
    '/api/orders',
    '/health',
  ];

  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];

  const res = http.get(`https://api.example.com${endpoint}`, {
    tags: { endpoint },
  });

  check(res, {
    'status is 200': (r) => r.status === 200,
    'no memory leak indicator': (r) => {
      // Check for memory-related errors
      const body = r.body;
      return !body.includes('OutOfMemory') &&
             !body.includes('Memory limit exceeded');
    },
    'response valid': (r) => {
      try {
        const json = JSON.parse(r.body);
        return json !== null;
      } catch {
        return r.status === 200;  // Allow non-JSON health checks
      }
    },
  });

  // Track custom error conditions
  if (res.status >= 500) {
    errorRate.add(1);
  }

  // Simulate realistic user think time (1-5 seconds)
  sleep(Math.random() * 4 + 1);

  // Log progress every 1000 iterations
  if (__ITER % 1000 === 0) {
    console.log(`VU ${__VU} completed ${__ITER} iterations`);
  }
}
```

## Distributed Load Testing

### Kubernetes with k6 Operator

```yaml
# k6-test-crd.yaml
apiVersion: k6.io/v1alpha1
kind: TestRun
metadata:
  name: distributed-load-test
spec:
  parallelism: 10  # Run across 10 pods
  script:
    configMap:
      name: k6-test-scripts
      file: load-test.js
  arguments: --out cloud
  runner:
    env:
      - name: K6_OUT
        value: 'cloud'
      - name: K6_CLOUD_TOKEN
        valueFrom:
          secretKeyRef:
            name: k6-secrets
            key: token
    resources:
      limits:
        cpu: '2'
        memory: '4Gi'
      requests:
        cpu: '1'
        memory: '2Gi'
```

## Running Load Tests

### Local Execution

```bash
# Run k6 test locally
k6 run k6-rest-api.js

# Run with custom environment variables
BASE_URL=https://staging.api.com k6 run k6-rest-api.js

# Run with specific VUs and duration
k6 run --vus 100 --duration 30s k6-rest-api.js

# Run browser tests (requires k6 v0.52+)
K6_BROWSER_HEADLESS=false k6 run k6-browser-hybrid.js

# Output to multiple destinations
k6 run --out json=results.json --out csv=results.csv --out cloud k6-test.js
```

### Cloud Execution

```bash
# Run on Grafana Cloud k6
k6 cloud run k6-rest-api.js

# Run with cloud output from local
k6 run --out cloud k6-rest-api.js

# Distributed cloud execution
k6 cloud run --distribution amazon:us:ashburn=50,amazon:de:frankfurt=50 k6-test.js
```

### CI/CD Integration (2026 Best Practices)

```yaml
# .github/workflows/load-test.yml
name: Load Test

on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly on Monday at 2 AM
  workflow_dispatch:     # Manual trigger
    inputs:
      environment:
        description: 'Environment to test'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production

jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup k6
        uses: grafana/setup-k6-action@v1
        with:
          k6-version: 'latest'

      - name: Run smoke test
        run: k6 run --vus 10 --duration 1m ./load-tests/smoke-test.js
        env:
          BASE_URL: ${{ github.event.inputs.environment == 'production' && secrets.PROD_URL || secrets.STAGING_URL }}

      - name: Run full load test
        run: k6 run ./load-tests/k6-rest-api.js
        env:
          BASE_URL: ${{ github.event.inputs.environment == 'production' && secrets.PROD_URL || secrets.STAGING_URL }}
          K6_CLOUD_TOKEN: ${{ secrets.K6_CLOUD_TOKEN }}
        continue-on-error: true  # Don't block on performance regression

      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: k6-results
          path: |
            results.json
            results.csv

      - name: Comment PR with results
        if: github.event_name == 'pull_request'
        uses: grafana/k6-report-action@v1
        with:
          file: results.json
```

## Performance Benchmarks (2026)

### Updated Thresholds

| Metric | Good | Warning | Critical |
|--------|------|---------|----------|
| Response Time (p50) | < 100ms | 100-300ms | > 300ms |
| Response Time (p95) | < 300ms | 300-800ms | > 800ms |
| Response Time (p99) | < 500ms | 500-1500ms | > 1500ms |
| Error Rate | < 0.1% | 0.1-0.5% | > 0.5% |
| Throughput | Baseline | -10% | -25% |
| LCP (Largest Contentful Paint) | < 2.5s | 2.5-4s | > 4s |
| FID (First Input Delay) | < 100ms | 100-300ms | > 300ms |
| CLS (Cumulative Layout Shift) | < 0.1 | 0.1-0.25 | > 0.25 |
| INP (Interaction to Next Paint) | < 200ms | 200-500ms | > 500ms |

## Best Practices (2026)

1. **Use Scenarios**: Define realistic user journeys instead of simple VU counts
2. **Arrival-rate Modeling**: Use arrival-rate executors for more realistic API load
3. **Browser + API Hybrid**: Combine protocol-level and browser-level testing
4. **Core Web Vitals**: Monitor LCP, FID, CLS, INP for user-facing applications
5. **Distributed Testing**: Use k6 Operator for large-scale tests
6. **AI-Assisted Authoring**: Use k6's AI assistant for generating test scripts
7. **Realistic Data**: Use production-like data volumes and patterns
8. **Gradual Ramp-up**: Always include warm-up periods
9. **Monitor Infrastructure**: Track server metrics alongside test metrics
10. **Fail on Thresholds**: Integrate with CI/CD gates for performance regression

## Resources

- [k6 Documentation](https://grafana.com/docs/k6/latest/)
- [k6 Browser Testing](https://grafana.com/docs/k6/latest/using-k6-browser/)
- [Core Web Vitals](https://web.dev/vitals/)
- [Grafana Cloud k6](https://grafana.com/products/cloud/k6/)

---

# Mutation Testing

Mutation testing tools and strategies. Updated with 2026 best practices and latest tool versions.

## Overview

This guide covers mutation testing techniques to verify the quality and effectiveness of your test suite. Mutation testing introduces small changes (mutations) to your code and checks if your tests catch them. If tests pass with mutated code, your test coverage has gaps.

## What is Mutation Testing?

**TL;DR**: Mutation testing introduces changes to your code, then runs your unit tests against the changed code. It is expected that your unit tests will now fail. If they don't fail, it might indicate your tests do not sufficiently cover the code.

Bugs, or *mutants*, are automatically inserted into your production code. Your tests are run for each mutant. If your tests *fail* then the mutant is *killed*. If your tests passed, the mutant *survived*. The higher the percentage of mutants killed, the more *effective* your tests are.

### Example

```python
# Stryker will find the return statement and decide to change it:
def isUserOldEnough(user):
    return user.age >= 18

# Possible mutations:
# 1. return user.age > 18;    # Changed >= to >
# 2. return user.age < 18;    # Reverse comparison
# 3. return false;            # Constant replacement
# 4. return true;             # Constant replacement

# Test that catches the mutation:
def test_age_boundary():
    assert isUserOldEnough({'age': 18}) is True   # Boundary
    assert isUserOldEnough({'age': 17}) is False  # Just below
    assert isUserOldEnough({'age': 19}) is True   # Just above
```

### Why Not Just Code Coverage?

Code coverage doesn't tell you everything about the effectiveness of your tests. Think about it: when was the last time you saw a test without an assertion, purely to increase the code coverage?

Imagine a sandwich covered with paste. Code coverage would tell you the bread is 80% covered with paste. Mutation testing, on the other hand, would tell you it is actually *chocolate* paste and not... well... something else.

## Tools by Language (2026)

### JavaScript/TypeScript: StrykerJS (v8.x)

StrykerJS is the most popular mutation testing framework for JavaScript, supporting React, Angular, VueJS, Svelte, NodeJS, and TypeScript.

**Installation:**

```bash
# Install Stryker and test runner
npm install --save-dev @stryker-mutator/core @stryker-mutator/jest-runner

# Alternative runners
npm install --save-dev @stryker-mutator/vitest-runner
npm install --save-dev @stryker-mutator/mocha-runner
npm install --save-dev @stryker-mutator/karma-runner
npm install --save-dev @stryker-mutator/jasmine-runner
```

**Configuration (stryker.config.json):**

```json
{
  "$schema": "https://raw.githubusercontent.com/stryker-mutator/stryker-js/master/packages/api/schema/stryker-schema.json",
  "mutate": [
    "src/**/*.ts",
    "!src/**/*.test.ts",
    "!src/**/__tests__/**"
  ],
  "testRunner": "jest",
  "reporters": [
    "progress",
    "clear-text",
    "html",
    "json"
  ],
  "coverageAnalysis": "perTest",
  "incremental": true,
  "incrementalFile": ".stryker/incremental.json",
  "mutator": {
    "plugins": []
  },
  "jest": {
    "projectType": "custom",
    "configFile": "jest.config.js"
  },
  "thresholds": {
    "high": 80,
    "low": 60,
    "break": 70
  }
}
```

**Running Stryker:**

```bash
# Run mutation testing
npx stryker run

# Run with incremental mode (faster for subsequent runs)
npx stryker run --incremental

# Force full run ignoring incremental
npx stryker run --force

# Run with specific config file
npx stryker run --config stryker.config.json

# Preview plan without running (dry run)
npx stryker run --dry-run

# View HTML report
open reports/mutation/mutation.html
```

**Vitest Configuration (2026):**

```json
{
  "testRunner": "vitest",
  "vitest": {
    "configFile": "vitest.config.ts"
  }
}
```

### Python: Mutmut (Latest)

```bash
# Install
pip install mutmut

# Run mutation testing
mutmut run

# Run with specific paths
mutmut run --paths-to-mutate=src/

# Run only on changed files (faster)
mutmut run --paths-to-mutate $(git diff --name-only HEAD~1 | grep "\.py$")

# View results
mutmut results

# Show surviving mutants
mutmut show 1  # Shows mutant #1
mutmut show all  # Shows all mutants

# Apply a mutant (for testing)
mutmut apply 1

# Generate HTML report
mutmut results --html
```

**Configuration (pyproject.toml):**

```toml
[tool.mutmut]
paths_to_mutate = "src/"
backup = false
runner = "python -m pytest"
tests_dir = "tests/"
mutate_copied_files = false

[tool.mutmut.target]
# Exclude specific files
exclude = [
    "src/**/test_*.py",
    "src/**/__init__.py",
]
```

**Example test that catches mutations:**

```python
# Original function
def is_positive(number):
    return number > 0

# Mutated version that mutmut might create:
# def is_positive(number):
#     return number >= 0  # Mutation: > becomes >=

# Good test that catches this:
def test_is_positive_boundary():
    assert is_positive(1) is True
    assert is_positive(0) is False   # Catches >= mutation!
    assert is_positive(-1) is False
```

### Java: PIT (Latest)

```xml
<!-- pom.xml -->
<plugin>
    <groupId>org.pitest</groupId>
    <artifactId>pitest-maven</artifactId>
    <version>1.15.0</version>
    <configuration>
        <targetClasses>
            <param>com.example.*</param>
        </targetClasses>
        <targetTests>
            <param>com.example.*Test</param>
        </targetTests>
        <mutators>
            <mutator>CONDITIONALS_BOUNDARY</mutator>
            <mutator>NEGATE_CONDITIONALS</mutator>
            <mutator>REMOVE_CONDITIONALS</mutator>
            <mutator>MATH</mutator>
            <mutator>INCREMENTS</mutator>
            <mutator>INVERT_NEGS</mutator>
            <mutator>RETURN_VALS</mutator>
            <mutator>VOID_METHOD_CALLS</mutator>
            <mutator>EMPTY_RETURNS</mutator>
            <mutator>NULL_RETURNS</mutator>
            <mutator>PRIMITIVE_RETURNS</mutator>
            <mutator>TRUE_RETURNS</mutator>
            <mutator>FALSE_RETURNS</mutator>
        </mutators>
        <thresholds>
            <mutationThreshold>70</mutationThreshold>
            <coverageThreshold>50</coverageThreshold>
        </thresholds>
        <timestampedReports>false</timestampedReports>
        <outputFormats>
            <outputFormat>HTML</outputFormat>
            <outputFormat>CSV</outputFormat>
        </outputFormats>
    </configuration>
</plugin>
```

```bash
# Run PIT
mvn org.pitest:pitest-maven:mutationCoverage

# Run with history (incremental)
mvn org.pitest:pitest-maven:mutationCoverage -DwithHistory=true

# View report
open target/pit-reports/*/index.html
```

### C#: Stryker.NET (v4.x)

```bash
# Install globally
dotnet tool install -g dotnet-stryker

# Or as local tool
dotnet new tool-manifest
dotnet tool install dotnet-stryker

# Run
dotnet stryker

# With options
dotnet stryker --break-at 80        # Fail if mutation score < 80%
dotnet stryker --mutation-level Advanced  # Use all mutators
dotnet stryker --since main         # Only test changed code
dotnet stryker --diff               # Enable incremental mode

# Configuration file (stryker-config.json)
{
  "stryker-config": {
    "project": "MyProject.csproj",
    "test-projects": ["MyProject.Tests.csproj"],
    "reporters": ["progress", "html", "json"],
    "mutation-level": "Advanced",
    "break-on-initial-test-failure": true,
    "thresholds": {
      "high": 80,
      "low": 60,
      "break": 70
    }
  }
}
```

### Scala: Stryker4s

```bash
# Add to plugins.sbt
addSbtPlugin("io.stryker-mutator" % "sbt-stryker4s" % "0.16.0")

# Run
sbt stryker

# Configuration (stryker4s.conf in project root)
stryker4s {
  mutate: ["src/main/scala/**/*.scala"]
  test-runner: {
    type: "sbt"
  }
  reporters: ["console", "html"]
  thresholds: {
    high: 80
    low: 60
    break: 70
  }
}
```

## Mutation Operators (2026)

### Arithmetic Operators

```python
# Original
result = a + b

# Possible mutations:
result = a - b    # Addition to subtraction
result = a * b    # Addition to multiplication
result = a / b    # Addition to division
result = a % b    # Addition to modulo
result = a         # Replace with left operand
result = b         # Replace with right operand
```

### Relational Operators (Boundary Mutations)

```python
# Original
if x > 10:

# Mutations:
if x >= 10:  # Boundary shift
if x < 10:   # Reverse comparison
if x <= 10:  # Reverse boundary
if x == 10:  # Equality
if x != 10:  # Inequality
if True:     # Constant replacement
if False:     # Constant replacement
```

### Logical Operators

```python
# Original
if a and b:

# Mutations:
if a or b:       # AND to OR
if not a and b:  # Negate left
if a and not b:  # Negate right
if False:        # Constant
if True:         # Constant
if a:            # Remove right
if b:            # Remove left
```

### Conditional Boundaries (Off-by-One)

```python
# Original
for i in range(10):
    process(i)

# Mutations:
for i in range(9):   # Off by one (decrement)
for i in range(11):  # Off by one (increment)
for i in range(0):   # Empty loop

# Original
while count < max:

# Mutations:
while count <= max:  # Change boundary
while count > max:   # Reverse
while True:          # Infinite loop
while False:         # Never execute
```

### Return Value Mutations

```python
# Original
def get_value():
    return 42

# Mutations:
def get_value():
    return 0      # Replace with 0
    return 1      # Replace with 1
    return -1     # Replace with -1
    return None   # Replace with None
    return ""     # Replace with empty string
    return []     # Replace with empty list
```

### Method Call Mutations

```python
# Original
def process():
    do_something()
    return result

# Mutations:
def process():
    # Remove do_something() call
    return result

# Original
list.append(item)

# Mutation:
# Remove append call (list unchanged)
```

### String Mutations (Stryker 2026)

```javascript
// Original
const message = "Hello, " + name;

// Mutations:
const message = "Hello, " - name;   // Concatenation to subtraction
const message = "Hello, ";          // Remove concatenation
const message = name;               // Remove prefix
```

### Modern Language Features (2026)

```javascript
// Optional chaining mutations
// Original:
const value = obj?.property?.nested;

// Mutations:
const value = obj.property?.nested;  // Remove first ?.
const value = obj?.property.nested;   // Remove second ?.
const value = obj.property.nested;   // Remove both ?.

// Nullish coalescing
// Original:
const value = input ?? defaultValue;

// Mutation:
const value = input || defaultValue;  // ?? to ||
const value = input && defaultValue;  // ?? to &&
const value = input;                   // Remove fallback

// Template literal mutations
// Original:
const msg = `Hello, ${name}!`;

// Mutations:
const msg = `Hello, ${name}`;      // Remove suffix
const msg = `Hello, !`;             // Remove placeholder
const msg = `Hello, !` + name;      // Split
const msg = "";                      // Empty string
```

## Interpreting Results

### Mutation Score

```
Mutation Score = (Killed Mutants / Total Mutants) × 100

Status indicators:
- Killed: Tests failed (good!)
- Survived: Tests passed (bad - coverage gap)
- Timeout: Tests took too long
- Skipped: Couldn't apply mutation
- Ignored: Mutant marked to ignore
- Error: Error during testing
```

### Target Scores (2026 Guidelines)

| Project Type | Minimum | Good | Excellent |
|--------------|---------|------|-----------|
| Greenfield | 70% | 80% | 90%+ |
| Legacy | 50% | 60% | 70%+ |
| Critical Systems | 80% | 90% | 95%+ |
| Libraries/Frameworks | 75% | 85% | 95%+ |

**Important**: 100% mutation score is NOT the goal. Some mutations are equivalent (don't change behavior) and some code is intentionally untested (e.g., error handling for impossible conditions).

### Reading Reports

Stryker HTML Report sections:
- **Overall**: Project-wide mutation score
- **By File**: Per-file breakdown
- **Survived**: Detailed view of surviving mutants
- **Killed**: All killed mutants (for verification)
- **Mutant States**: Timeline of mutant testing

## CI/CD Integration

### GitHub Actions (2026 Best Practices)

```yaml
# .github/workflows/mutation-test.yml
name: Mutation Testing

on:
  push:
    branches: [main]
  pull_request:
    paths:
      - 'src/**'
      - 'tests/**'

jobs:
  mutation-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Needed for incremental mode

      # JavaScript/TypeScript with Stryker
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Cache mutation testing results
        uses: actions/cache@v4
        with:
          path: .stryker
          key: stryker-${{ runner.os }}-${{ hashFiles('src/**') }}
          restore-keys: |
            stryker-${{ runner.os }}-

      - name: Run mutation tests (incremental)
        run: npx stryker run --incremental

      - name: Check mutation score
        run: |
          SCORE=$(cat reports/mutation/mutation.json | jq -r '.metrics.mutationScore')
          echo "Mutation score: $SCORE"
          if (( $(echo "$SCORE < 70" | bc -l) )); then
            echo "::error::Mutation score $SCORE% is below threshold of 70%"
            exit 1
          fi

      - name: Upload mutation report
        uses: actions/upload-artifact@v4
        with:
          name: mutation-report
          path: reports/mutation/

      - name: Comment PR with results
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const report = JSON.parse(fs.readFileSync('reports/mutation/mutation.json'));
            const metrics = report.metrics;

            const body = `## 🧬 Mutation Test Results

            | Metric | Value |
            |--------|-------|
            | **Mutation Score** | ${metrics.mutationScore.toFixed(1)}% |
            | Killed | ${metrics.killed} |
            | Survived | ${metrics.survived} |
            | Timeout | ${metrics.timeout} |
            | Ignored | ${metrics.ignored} |

            ${metrics.mutationScore >= 70 ? '✅ **PASSED**' : '❌ **FAILED**'} - Threshold: 70%

            <details>
            <summary>View full report</summary>

            - Killed: ${metrics.killed} mutants
            - Survived: ${metrics.survived} mutants
            - Timeout: ${metrics.timeout} mutants
            - No coverage: ${metrics.noCoverage} mutants

            </details>
            `;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: body
            });
```

### Python with Mutmut

```yaml
# .github/workflows/mutation-python.yml
name: Mutation Testing (Python)

on: [push, pull_request]

jobs:
  mutation-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install mutmut

      - name: Run mutation tests
        run: mutmut run

      - name: Generate results
        run: |
          mutmut results > mutation-results.txt
          mutmut results --html

      - name: Check score
        run: |
          SCORE=$(mutmut results | grep "Mutation score" | awk '{print $3}' | tr -d '%')
          if (( $(echo "$SCORE < 60" | bc -l) )); then
            echo "Mutation score $SCORE% below threshold!"
            exit 1
          fi

      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: mutation-report
          path: html/
```

### Quality Gates

```bash
#!/bin/bash
# mutation-gate.sh - Universal quality gate

MIN_SCORE=${1:-70}
TOOL=${2:-stryker}  # stryker, mutmut, pitest, stryker-net

case $TOOL in
  stryker)
    SCORE=$(cat reports/mutation/mutation.json | jq -r '.metrics.mutationScore')
    ;;
  mutmut)
    SCORE=$(mutmut results | grep "Mutation score" | awk '{print $3}' | tr -d '%')
    ;;
  pitest)
    SCORE=$(cat target/pit-reports/*/mutations.xml | grep -o 'mutationScore="[^"]*"' | cut -d'"' -f2)
    ;;
  stryker-net)
    SCORE=$(cat mutation-report.json | jq -r '.MutationScore')
    ;;
esac

echo "Tool: $TOOL"
echo "Minimum required: $MIN_SCORE%"
echo "Actual score: $SCORE%"

if (( $(echo "$SCORE < $MIN_SCORE" | bc -l) )); then
    echo "❌ FAILED: Mutation score below threshold"
    exit 1
else
    echo "✅ PASSED: Mutation score meets threshold"
    exit 0
fi
```

## Incremental Mutation Testing (2026)

### Why Incremental?

Full mutation testing can be slow. Incremental mode only tests:
- New/changed code
- Mutants affected by code changes
- Regression tests for previously surviving mutants

### StrykerJS Incremental Mode

```json
{
  "incremental": true,
  "incrementalFile": ".stryker/incremental.json",

  // Force full run when needed
  "force": false  // Set to true for CI, false for local
}
```

**Best Practices:**
- Use `--incremental` for local development (fast feedback)
- Run full run weekly or before releases
- Cache the incremental file in CI
- Force full run on `main` branch merges

### Mutmut Incremental

```bash
# Run only on changed files
mutmut run --paths-to-mutate $(git diff --name-only HEAD~1 | grep "\.py$")

# Or with since flag
mutmut run --since-ref=origin/main
```

### PIT History

```bash
# Enable history tracking
mvn org.pitest:pitest-maven:mutationCoverage -DwithHistory=true

# Faster incremental run
mvn org.pitest:pitest-maven:mutationCoverage -DhistoryInputFile=target/pit-history.txt
```

## Improving Mutation Score

### Common Gaps and Solutions

1. **Boundary Testing**

```python
# Bad - doesn't test boundary
def test_age_verification():
    assert is_adult(25) is True
    assert is_adult(15) is False

# Good - tests boundary
def test_age_verification():
    assert is_adult(18) is True   # Boundary
    assert is_adult(17) is False  # Just below
    assert is_adult(19) is True    # Just above
```

1. **Exception Testing**

```python
# Bad - no exception testing
def test_divide():
    assert divide(10, 2) == 5

# Good - tests exceptions
def test_divide():
    assert divide(10, 2) == 5
    with pytest.raises(ZeroDivisionError):
        divide(10, 0)
    with pytest.raises(TypeError):
        divide("10", 2)
```

1. **State Verification (Not Just Return Values)**

```python
# Bad - only tests return value
def test_add_item():
    cart = Cart()
    assert cart.add("apple") == True

# Good - tests state change
def test_add_item():
    cart = Cart()
    cart.add("apple")
    assert "apple" in cart.items
    assert cart.count == 1
    assert cart.total > 0
```

1. **Negative Testing**

```python
# Test what shouldn't happen
def test_invalid_input_rejected():
    assert process(None) is False
    assert process("") is False
    assert process(-1) is False
```

## Handling Equivalent Mutants

Some mutants are "equivalent" - they don't actually change behavior:

```python
# Original
def calculate(a, b):
    return (a + b) * 2

# This mutation is equivalent:
def calculate(a, b):
    return (a + b) + (a + b)  # Same as * 2
```

### Strategies

1. **Ignore Specific Mutants:**

```javascript
// Stryker: Disable specific mutants
// Stryker disable next-line
const value = expensiveOperation();  // Won't mutate this line

// Or with comment
def calculate(a, b):  # mutmut: ignore
    return (a + b) * 2  # This mutant is equivalent
```

1. **Configure Mutators:**

```json
{
  "mutator": {
    "excludedMutations": [
      "StringLiteral",
      "ArrayDeclaration"
    ]
  }
}
```

1. **Accept Imperfection**:
   - 100% mutation score is not realistic
   - Focus on improving over time
   - Document known equivalent mutants

## Best Practices (2026)

1. **Start Small**: Focus on critical business logic first
2. **Use Incremental Mode**: For faster feedback during development
3. **Set Realistic Thresholds**: Increase gradually, not all at once
4. **Integrate with CI**: Run on PRs with reasonable thresholds
5. **Focus on Critical Code**: Business logic over boilerplate
6. **Review Surviving Mutants**: Understand why they survived
7. **Document Exceptions**: Track equivalent mutants and exclusions
8. **Team Education**: Train team on writing mutation-killing tests
9. **Balance Speed vs Coverage**: Use full runs periodically, incremental daily
10. **Dashboard Integration**: Track mutation score trends over time

## Stryker Dashboard

Upload results to Stryker Dashboard for tracking:

```bash
# Enable dashboard reporter
npx stryker run --reporters dashboard

# Requires API key in environment
export STRYKER_DASHBOARD_API_KEY=your_key
```

Features:
- Historical trend tracking
- Branch comparison
- PR status badges
- Team visibility

## Resources

- [Stryker Mutator](https://stryker-mutator.io/)
- [StrykerJS Documentation](https://stryker-mutator.io/docs/stryker-js/introduction/)
- [Mutation Testing Elements](https://github.com/stryker-mutator/mutation-testing-elements)
- [Mutmut](https://github.com/mutmut-mutator/mutmut)
- [PIT](https://pitest.org/)
- [Stryker.NET](https://stryker-mutator.io/docs/stryker-net/introduction/)

---

# Property-Based Testing Patterns

Advanced patterns for property-based testing with Hypothesis, QuickCheck, and fast-check.

## Stateful Testing

Test stateful systems with model-based testing.

### Python with Hypothesis

```python
from hypothesis import given, strategies as st, settings
from hypothesis.stateful import RuleBasedStateMachine, rule, invariant, precondition

class DatabaseMachine(RuleBasedStateMachine):
    def __init__(self):
        super().__init__()
        self.database = {}

    @rule(key=st.text(min_size=1), value=st.integers())
    def write(self, key, value):
        self.database[key] = value

    @rule(key=st.text(min_size=1))
    def read(self, key):
        return self.database.get(key)

    @rule(key=st.text(min_size=1))
    def delete(self, key):
        if key in self.database:
            del self.database[key]

    @invariant()
    def keys_are_strings(self):
        assert all(isinstance(k, str) for k in self.database.keys())

    @invariant()
    def values_are_integers(self):
        assert all(isinstance(v, int) for v in self.database.values())

TestDatabase = DatabaseMachine.TestCase
```

## Custom Strategies

### Composite Strategies

```python
from hypothesis import given, strategies as st

email_strategy = st.builds(
    lambda user, domain: f"{user}@{domain}",
    user=st.text(alphabet="abcdefghijklmnopqrstuvwxyz0123456789.-", min_size=1, max_size=64),
    domain=st.sampled_from(["example.com", "test.org", "mail.net"])
)

# Date range strategy
date_range_strategy = st.tuples(
    st.dates(min_value=date(2020, 1, 1), max_value=date(2024, 12, 31)),
    st.dates(min_value=date(2020, 1, 1), max_value=date(2024, 12, 31))
).filter(lambda x: x[0] <= x[1])
```

### Recursive Data Structures

```python
from hypothesis import given, strategies as st

json_strategy = st.recursive(
    st.one_of(st.none(), st.booleans(), st.integers(), st.text()),
    lambda children: st.one_of(
        st.lists(children),
        st.dictionaries(st.text(), children)
    ),
    max_leaves=10
)

@given(json_strategy)
def test_json_handling(data):
    # Test that your code handles any JSON-like structure
    result = process_json(data)
    assert result is not None
```

## Common Properties

### Roundtrip Properties

```python
@given(st.text())
def test_serialization_roundtrip(text):
    """Serializing then deserializing should restore original."""
    serialized = serialize(text)
    deserialized = deserialize(serialized)
    assert deserialized == text
```

### Idempotence

```python
@given(st.lists(st.integers()))
def test_sorting_idempotent(lst):
    """Sorting twice equals sorting once."""
    once = sorted(lst)
    twice = sorted(once)
    assert once == twice
```

### Commutativity

```python
@given(st.integers(), st.integers())
def test_addition_commutative(a, b):
    """a + b == b + a"""
    assert a + b == b + a
```

### Associativity

```python
@given(st.lists(st.integers()), st.lists(st.integers()), st.lists(st.integers()))
def test_list_concat_associative(a, b, c):
    """(a + b) + c == a + (b + c)"""
    left = (a + b) + c
    right = a + (b + c)
    assert left == right
```

### Inverses

```python
@given(st.integers())
def test_increment_decrement_inverse(x):
    """decrement(increment(x)) == x"""
    assert decrement(increment(x)) == x
```

## Fast-Check (JavaScript)

```javascript
const fc = require('fast-check');

// Property test
test('should always contain its substrings', () => {
  fc.assert(
    fc.property(fc.string(), fc.string(), (a, b) => {
      expect((a + b)).toContain(a);
      expect((a + b)).toContain(b);
    })
  );
});

// Async property test
test('should handle async code', async () => {
  await fc.assert(
    fc.asyncProperty(fc.string(), async (text) => {
      const result = await asyncProcess(text);
      expect(result).toBeDefined();
    })
  );
});
```

---

# Test Maintenance

Test health monitoring and maintenance strategies. Updated with 2026 best practices for flaky test management and test suite health monitoring.

## Overview

This guide covers strategies for keeping your test suite healthy, reliable, and maintainable over time. Includes modern approaches to flaky test detection, quarantine management, and AI-assisted test maintenance.

## Test Health Metrics (2026)

### Key Metrics to Track

```python
TEST_HEALTH_METRICS = {
    'test_count': 'Total number of tests',
    'flaky_test_rate': 'Percentage of tests that fail randomly (>20% variance)',
    'test_duration': 'Time to run full test suite',
    'test_coverage': 'Code coverage percentage',
    'mutation_score': 'Mutation testing effectiveness',
    'broken_test_rate': 'Tests failing consistently',
    'test_duplication': 'Similar or duplicate tests',
    'obsolete_tests': 'Tests for removed features',
    'test_debt': 'TODO/FIXME comments in tests',
    'ci_failure_rate': 'Percentage of CI runs with test failures',
    'mean_time_to_fix': 'Average time to fix broken tests',
    'test_parallelization': 'Tests that can run in parallel',
}
```

### Health Dashboard (2026)

```python
import json
from datetime import datetime, timedelta
from pathlib import Path
from dataclasses import dataclass
from typing import List, Dict, Optional
import requests

@dataclass
class TestMetrics:
    timestamp: datetime
    total_tests: int
    passed: int
    failed: int
    skipped: int
    duration_seconds: float
    flaky_tests: List[str]
    coverage_percent: float
    mutation_score: Optional[float]

class TestHealthMonitor:
    def __init__(self, test_results_dir: str, history_days: int = 30):
        self.results_dir = Path(test_results_dir)
        self.history_days = history_days
        self.health_data: Dict[str, List[Dict]] = {}

    def analyze_test_runs(self) -> List[TestMetrics]:
        """Analyze test results from last N days with machine learning-based flaky detection"""
        cutoff = datetime.now() - timedelta(days=self.history_days)
        metrics = []

        for result_file in self.results_dir.glob('*.json'):
            date = datetime.fromtimestamp(result_file.stat().st_mtime)
            if date < cutoff:
                continue

            with open(result_file) as f:
                results = json.load(f)

            metric = self._parse_results(results, date)
            metrics.append(metric)

        return metrics

    def identify_flaky_tests_ml(self, min_runs: int = 5) -> List[Dict]:
        """ML-enhanced flaky test detection using variance analysis"""
        flaky = []

        for test_name, runs in self.health_data.items():
            if len(runs) < min_runs:
                continue

            results = [r['status'] for r in runs]
            pass_count = results.count('passed')
            fail_count = results.count('failed')
            total = len(results)

            pass_rate = pass_count / total

            # ML-based detection: tests with pass rate between 20-80% are flaky
            if 0.2 <= pass_rate <= 0.8:
                # Calculate variance to determine severity
                variance = self._calculate_variance(runs)

                flaky.append({
                    'test': test_name,
                    'pass_rate': pass_rate,
                    'total_runs': total,
                    'fail_count': fail_count,
                    'variance': variance,
                    'severity': 'high' if variance > 0.5 else 'medium',
                    'trend': self._calculate_trend(runs),
                })

        return sorted(flaky, key=lambda x: x['variance'], reverse=True)

    def predict_test_health(self) -> Dict:
        """Predict future test suite health based on trends"""
        metrics = self.analyze_test_runs()

        if len(metrics) < 7:
            return {'prediction': 'insufficient_data'}

        # Calculate trends
        durations = [m.duration_seconds for m in metrics]
        flaky_counts = [len(m.flaky_tests) for m in metrics]

        duration_trend = self._linear_regression_slope(durations)
        flaky_trend = self._linear_regression_slope(flaky_counts)

        return {
            'duration_trend': 'increasing' if duration_trend > 0 else 'decreasing',
            'flaky_trend': 'increasing' if flaky_trend > 0 else 'decreasing',
            'predicted_duration_in_30_days': durations[-1] + (duration_trend * 30),
            'predicted_flaky_in_30_days': flaky_counts[-1] + (flaky_trend * 30),
            'health_score': self._calculate_health_score(metrics[-1]),
        }

    def _calculate_health_score(self, metric: TestMetrics) -> float:
        """Calculate overall health score 0-100"""
        scores = {
            'pass_rate': (metric.passed / metric.total_tests) * 30 if metric.total_tests > 0 else 0,
            'coverage': min(metric.coverage_percent / 80 * 20, 20),
            'speed': max(0, 20 - metric.duration_seconds / 60),
            'stability': max(0, 30 - len(metric.flaky_tests) * 3),
        }
        return sum(scores.values())

    def generate_report(self) -> Dict:
        """Generate comprehensive health report"""
        metrics = self.analyze_test_runs()
        flaky = self.identify_flaky_tests_ml()
        prediction = self.predict_test_health()

        if not metrics:
            return {'error': 'No test data found'}

        latest = metrics[-1]

        return {
            'timestamp': datetime.now().isoformat(),
            'summary': {
                'total_tests': latest.total_tests,
                'pass_rate': latest.passed / latest.total_tests if latest.total_tests > 0 else 0,
                'duration_minutes': latest.duration_seconds / 60,
                'coverage': latest.coverage_percent,
                'mutation_score': latest.mutation_score,
            },
            'flaky_tests': {
                'count': len(flaky),
                'high_severity': [f for f in flaky if f['severity'] == 'high'],
                'list': flaky,
            },
            'prediction': prediction,
            'health_score': self._calculate_health_score(latest),
            'recommendations': self._generate_recommendations(flaky, latest),
            'trend_data': {
                'last_7_days': [
                    {
                        'date': m.timestamp.isoformat(),
                        'pass_rate': m.passed / m.total_tests if m.total_tests > 0 else 0,
                        'duration': m.duration_seconds,
                        'flaky_count': len(m.flaky_tests),
                    }
                    for m in metrics[-7:]
                ]
            }
        }

    def _generate_recommendations(self, flaky: List[Dict], latest: TestMetrics) -> List[str]:
        """AI-generated recommendations based on metrics"""
        recommendations = []

        if len(flaky) > 5:
            recommendations.append(
                f"🔴 Critical: {len(flaky)} flaky tests detected. Schedule immediate repair sprint."
            )
        elif len(flaky) > 0:
            recommendations.append(
                f"🟡 Warning: {len(flaky)} flaky tests. Quarantine and fix within 1 week."
            )

        if latest.duration_seconds > 600:  # > 10 minutes
            recommendations.append(
                f"🟡 Slow test suite ({latest.duration_seconds/60:.1f}min). Consider parallelization."
            )

        if latest.coverage_percent < 70:
            recommendations.append(
                f"🟡 Low coverage ({latest.coverage_percent:.1f}%). Target: 80%+"
            )

        return recommendations

# Usage example
if __name__ == '__main__':
    monitor = TestHealthMonitor('./test_results')
    report = monitor.generate_report()
    print(json.dumps(report, indent=2))
```

## Flaky Test Management (2026)

### Advanced Flaky Test Detection

```python
# flaky_detector_advanced.py
import pytest
import os
from collections import defaultdict
from typing import Set, Dict, List
import hashlib

class AdvancedFlakyTestDetector:
    """
    Advanced flaky test detection with:
    - Environment correlation analysis
    - Test dependency detection
    - Flaky pattern recognition
    """

    def __init__(self):
        self.test_history: Dict[str, List[Dict]] = defaultdict(list)
        self.env_history: Dict[str, Dict] = {}
        self.dependency_graph: Dict[str, Set[str]] = defaultdict(set)

    def record_result(self, test_name: str, passed: bool,
                      duration_ms: float, env_info: Dict):
        """Record test result with environment metadata"""
        run_id = hashlib.md5(
            f"{test_name}{datetime.now()}".encode()
        ).hexdigest()[:8]

        self.test_history[test_name].append({
            'run_id': run_id,
            'passed': passed,
            'timestamp': datetime.now(),
            'duration_ms': duration_ms,
            'env': env_info,
            'ci_run_id': os.environ.get('GITHUB_RUN_ID', 'local'),
        })

        # Keep last 20 runs
        self.test_history[test_name] = self.test_history[test_name][-20:]

    def is_flaky(self, test_name: str,
                 min_variance_threshold: float = 0.2) -> Dict:
        """Determine if a test is flaky with detailed analysis"""
        history = self.test_history.get(test_name, [])

        if len(history) < 5:
            return {'is_flaky': False, 'reason': 'insufficient_data'}

        results = [h['passed'] for h in history]
        pass_rate = sum(results) / len(results)

        # Calculate variance
        variance = sum((r - pass_rate) ** 2 for r in results) / len(results)

        # Check environment correlation
        env_analysis = self._analyze_env_correlation(test_name)

        # Check for timing issues
        timing_analysis = self._analyze_timing_issues(test_name)

        is_flaky = (
            0.2 < pass_rate < 0.8 or  # Unstable pass rate
            variance > min_variance_threshold or
            env_analysis['env_correlated'] or
            timing_analysis['has_timing_issues']
        )

        return {
            'is_flaky': is_flaky,
            'pass_rate': pass_rate,
            'variance': variance,
            'sample_size': len(history),
            'env_correlation': env_analysis,
            'timing_issues': timing_analysis,
            'recommended_action': self._recommend_action(
                pass_rate, variance, env_analysis, timing_analysis
            ),
        }

    def _analyze_env_correlation(self, test_name: str) -> Dict:
        """Analyze if failures correlate with specific environments"""
        history = self.test_history.get(test_name, [])
        env_failures: Dict[str, int] = defaultdict(int)
        env_total: Dict[str, int] = defaultdict(int)

        for run in history:
            env_key = f"{run['env'].get('os')}-{run['env'].get('python')}"
            env_total[env_key] += 1
            if not run['passed']:
                env_failures[env_key] += 1

        # Find environments with high failure rates
        problematic_envs = {
            env: fails / env_total[env]
            for env, fails in env_failures.items()
            if env_total[env] > 2 and fails / env_total[env] > 0.5
        }

        return {
            'env_correlated': len(problematic_envs) > 0,
            'problematic_envs': problematic_envs,
            'recommendation': 'environment_specific' if problematic_envs else 'general',
        }

    def _analyze_timing_issues(self, test_name: str) -> Dict:
        """Analyze if test has timing-related flakiness"""
        history = self.test_history.get(test_name, [])

        if len(history) < 5:
            return {'has_timing_issues': False}

        durations = [h['duration_ms'] for h in history]
        avg_duration = sum(durations) / len(durations)

        # Check for high variance in duration (indicates timing issues)
        duration_variance = sum((d - avg_duration) ** 2 for d in durations) / len(durations)

        # Check if failures correlate with slow runs
        slow_failures = sum(
            1 for h in history
            if not h['passed'] and h['duration_ms'] > avg_duration * 1.5
        )

        return {
            'has_timing_issues': duration_variance > 1000 or slow_failures > 1,
            'avg_duration_ms': avg_duration,
            'duration_variance': duration_variance,
            'slow_failure_count': slow_failures,
        }

    def _recommend_action(self, pass_rate: float, variance: float,
                          env_analysis: Dict, timing_analysis: Dict) -> str:
        """Recommend action based on analysis"""
        if env_analysis['env_correlated']:
            return 'investigate_environment'
        elif timing_analysis['has_timing_issues']:
            return 'add_synchronization'
        elif pass_rate < 0.5:
            return 'quarantine_and_fix'
        elif variance > 0.3:
            return 'increase_reruns'
        else:
            return 'monitor'

    def detect_test_dependencies(self) -> List[Dict]:
        """Detect tests that may have hidden dependencies"""
        dependencies = []

        test_names = list(self.test_history.keys())

        for i, test1 in enumerate(test_names):
            for test2 in test_names[i+1:]:
                # Check if tests fail together often
                correlation = self._calculate_failure_correlation(test1, test2)

                if correlation > 0.7:  # Strong correlation
                    dependencies.append({
                        'test1': test1,
                        'test2': test2,
                        'correlation': correlation,
                        'suggestion': 'isolate_tests',
                    })

        return dependencies

# Pytest plugin integration
@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item, call):
    """Hook to record test results for flaky detection"""
    outcome = yield
    report = outcome.get_result()

    detector = item.config._flaky_detector

    if report.when == 'call':
        detector.record_result(
            test_name=item.nodeid,
            passed=report.passed,
            duration_ms=call.duration * 1000,
            env_info={
                'os': os.environ.get('RUNNER_OS', 'unknown'),
                'python': os.environ.get('PYTHON_VERSION', 'unknown'),
                'ci': os.environ.get('CI', 'false'),
            }
        )
```

### Smart Quarantine System

```python
# quarantine_manager.py
import json
from pathlib import Path
from datetime import datetime, timedelta
from typing import List, Dict, Optional
import yaml

class QuarantineManager:
    """
    Intelligent test quarantine system with:
    - Automatic quarantine based on flakiness
    - Graduated re-entry process
    - Impact analysis
    """

    def __init__(self, quarantine_file: str = '.test_quarantine.yml'):
        self.quarantine_file = Path(quarantine_file)
        self.quarantine: Dict = self._load_quarantine()

    def _load_quarantine(self) -> Dict:
        """Load quarantine configuration"""
        if self.quarantine_file.exists():
            with open(self.quarantine_file) as f:
                return yaml.safe_load(f) or {'quarantined': [], 'history': []}
        return {'quarantined': [], 'history': []}

    def _save_quarantine(self):
        """Save quarantine configuration"""
        with open(self.quarantine_file, 'w') as f:
            yaml.dump(self.quarantine, f, default_flow_style=False)

    def quarantine_test(self, test_name: str, reason: str,
                        detector_result: Dict, quarantine_by: str):
        """Add test to quarantine"""
        entry = {
            'test_name': test_name,
            'reason': reason,
            'quarantine_date': datetime.now().isoformat(),
            'quarantine_by': quarantine_by,
            'detector_result': detector_result,
            'pass_rate': detector_result.get('pass_rate', 0),
            'reentry_attempts': 0,
            'status': 'quarantined',
            'jira_ticket': None,
            'notes': [],
        }

        # Check if already quarantined
        existing = next(
            (q for q in self.quarantine['quarantined'] if q['test_name'] == test_name),
            None
        )

        if existing:
            existing.update(entry)
            existing['notes'].append(f"Re-quarantined on {datetime.now().isoformat()}")
        else:
            self.quarantine['quarantined'].append(entry)

        self._save_quarantine()

        # Generate notification
        self._notify_quarantine(entry)

    def attempt_reentry(self, test_name: str, ci_results: List[bool]) -> Dict:
        """Attempt to re-enter test from quarantine"""
        entry = next(
            (q for q in self.quarantine['quarantined'] if q['test_name'] == test_name),
            None
        )

        if not entry:
            return {'success': False, 'error': 'Test not in quarantine'}

        entry['reentry_attempts'] += 1

        # Require 10 consecutive passes for reentry
        if len(ci_results) >= 10 and all(ci_results[-10:]):
            # Move to history
            entry['status'] = 'reentered'
            entry['reentry_date'] = datetime.now().isoformat()
            self.quarantine['history'].append(entry)
            self.quarantine['quarantined'] = [
                q for q in self.quarantine['quarantined']
                if q['test_name'] != test_name
            ]
            self._save_quarantine()

            return {
                'success': True,
                'message': f'Test {test_name} successfully reentered',
                'total_attempts': entry['reentry_attempts'],
            }

        self._save_quarantine()

        return {
            'success': False,
            'message': f'Reentry failed: only {sum(ci_results)}/{len(ci_results)} passes',
            'consecutive_passes_required': 10 - sum(ci_results[-10:]),
            'attempts_remaining': 5 - entry['reentry_attempts'],
        }

    def get_quarantine_report(self) -> Dict:
        """Generate quarantine status report"""
        quarantined = self.quarantine['quarantined']
        history = self.quarantine['history']

        return {
            'summary': {
                'currently_quarantined': len(quarantined),
                'total_ever_quarantined': len(quarantined) + len(history),
                'successfully_reentered': len([h for h in history if h['status'] == 'reentered']),
                'quarantine_age_avg_days': self._avg_quarantine_age(quarantined),
            },
            'quarantined_tests': [
                {
                    'test_name': q['test_name'],
                    'days_in_quarantine': (
                        datetime.now() - datetime.fromisoformat(q['quarantine_date'])
                    ).days,
                    'pass_rate': q['pass_rate'],
                    'reason': q['reason'],
                    'reentry_attempts': q['reentry_attempts'],
                }
                for q in quarantined
            ],
            'recommendations': self._generate_quarantine_recommendations(quarantined),
        }

    def _generate_quarantine_recommendations(self, quarantined: List[Dict]) -> List[str]:
        """Generate recommendations for quarantined tests"""
        recommendations = []

        old_quarantines = [
            q for q in quarantined
            if (datetime.now() - datetime.fromisoformat(q['quarantine_date'])).days > 30
        ]

        if old_quarantines:
            recommendations.append(
                f"⚠️ {len(old_quarantines)} tests quarantined >30 days. Consider deletion."
            )

        high_attempts = [q for q in quarantined if q['reentry_attempts'] > 3]
        if high_attempts:
            recommendations.append(
                f"🔴 {len(high_attempts)} tests with >3 reentry attempts. Needs investigation."
            )

        return recommendations

# Pytest integration for quarantine
# conftest.py
import pytest
import os

# Global quarantine manager
_quarantine_mgr = None

def pytest_configure(config):
    global _quarantine_mgr
    _quarantine_mgr = QuarantineManager()
    config._quarantine = _quarantine_mgr

@pytest.hookimpl(tryfirst=True)
def pytest_runtest_setup(item):
    """Skip quarantined tests in CI unless explicitly running quarantined"""
    if os.environ.get('CI') == 'true' and not os.environ.get('RUN_QUARANTINED'):
        quarantine = item.config._quarantine
        test_name = item.nodeid

        entry = next(
            (q for q in quarantine.quarantine['quarantined'] if q['test_name'] == test_name),
            None
        )

        if entry:
            pytest.skip(f"Test is quarantined: {entry['reason']}")

# Decorator for marking potentially flaky tests
@pytest.mark.flaky(reruns=3, reruns_delay=1)
def quarantine_if_fails(reruns=3):
    """Decorator to auto-quarantine if test fails consistently"""
    def decorator(test_func):
        @pytest.mark.flaky(reruns=reruns)
        @wraps(test_func)
        def wrapper(*args, **kwargs):
            return test_func(*args, **kwargs)
        return wrapper
    return decorator
```

### Quarantine Configuration File

```yaml
# .test_quarantine.yml
quarantined:
  - test_name: test_network_timeout
    reason: Intermittent network timeouts in CI
    quarantine_date: '2026-01-15T10:30:00'
    quarantine_by: 'ci-system'
    pass_rate: 0.65
    reentry_attempts: 1
    status: quarantined
    jira_ticket: TEST-1234
    notes:
      - Re-quarantined on 2026-01-20T08:15:00

  - test_name: test_race_condition
    reason: Race condition under high load
    quarantine_date: '2026-01-10T14:22:00'
    quarantine_by: 'developer'
    pass_rate: 0.45
    reentry_attempts: 3
    status: quarantined
    jira_ticket: TEST-1235
    notes: []

history:
  - test_name: test_fixed_flaky
    reason: Timing issue resolved
    quarantine_date: '2026-01-01T09:00:00'
    reentry_date: '2026-01-05T16:30:00'
    status: reentered
    reentry_attempts: 2
```

## Test Suite Optimization

### Parallel Execution (2026)

```python
# pytest.ini
[pytest]
# Auto-detect CPU cores
addopts = -n auto --dist loadfile

# Or specific configuration
addopts = -n 8 --dist loadscope --maxprocesses 8

# Combine with testmon for smart selection
addopts = -n auto --testmon

# Disable parallel for specific markers
markers =
    serial: marks tests that cannot run in parallel
```

### Smart Test Selection

```bash
# Only run affected tests (using pytest-testmon)
pytest --testmon  # Run only tests affected by changes

# Using pytest-smartselect
pytest --smartselect  # Run based on git changes

# Run based on git diff
pytest $(git diff --name-only main | grep test | sed 's/.py//')

# Run tests related to changed code (coverage-based)
pytest --cov=src --cov-context=test --cov-report=json
```

### Test Categorization Matrix

```python
# test_categories.py
import pytest

# Priority markers
@pytest.mark.critical  # Always run, never skip
@pytest.mark.high      # Run in all CI jobs
@pytest.mark.medium    # Run in main CI only
@pytest.mark.low       # Run nightly only

# Speed markers
@pytest.mark.fast      # < 100ms
@pytest.mark.slow      # > 1s
@pytest.mark.timeout(30)  # Custom timeout

# Type markers
@pytest.mark.unit      # Fast, isolated
@pytest.mark.integration  # With dependencies
@pytest.mark.e2e       # Full system
@pytest.mark.contract  # API contract tests

# Flakiness markers
@pytest.mark.flaky(reruns=3, only_rerun=['TimeoutException'])
@pytest.mark.serial    # Cannot run in parallel
@pytest.mark.order(1)  # Explicit ordering

def test_critical_path():
    """Critical business path test"""
    pass

@pytest.mark.slow
@pytest.mark.integration
def test_database_migration():
    """Slow integration test"""
    pass

@pytest.mark.flaky(reruns=5, reruns_delay=2)
@pytest.mark.timeout(60)
def test_external_api():
    """Flaky external API test"""
    pass
```

### CI Configuration for Categorized Tests

```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  fast-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run fast tests
        run: pytest -m "fast and not flaky" --timeout=60

  main-tests:
    runs-on: ubuntu-latest
    needs: fast-tests
    steps:
      - uses: actions/checkout@v4
      - name: Run main test suite
        run: pytest -m "not flaky and not slow" -n auto --cov=src

      - name: Upload coverage
        uses: codecov/codecov-action@v4

  flaky-tests:
    runs-on: ubuntu-latest
    if: github.event_name == 'schedule'  # Nightly only
    steps:
      - uses: actions/checkout@v4
      - name: Run quarantined tests
        run: pytest -m "flaky" --reruns 5
        continue-on-error: true

  slow-tests:
    runs-on: ubuntu-latest
    if: github.event_name == 'schedule'
    steps:
      - uses: actions/checkout@v4
      - name: Run slow tests
        run: pytest -m "slow" --timeout=600
```

## AI-Assisted Test Maintenance (2026)

### Automatic Flaky Test Diagnosis

```python
# ai_flaky_diagnosis.py
import openai
from typing import Dict, List

class AIFlakyDiagnosis:
    """Use AI to diagnose root causes of flaky tests"""

    def __init__(self, api_key: str):
        self.client = openai.OpenAI(api_key=api_key)

    def diagnose_flaky_test(self, test_code: str,
                          failure_logs: List[str],
                          success_logs: List[str]) -> Dict:
        """AI analysis of flaky test root cause"""

        prompt = f"""
        Analyze this flaky test and determine the likely root cause:

        Test Code:
        ```python
        {test_code}
        ```

        Failure Logs:
        {chr(10).join(failure_logs[:5])}

        Success Logs:
        {chr(10).join(success_logs[:5])}

        Analyze:
        1. What makes this test flaky?
        2. What patterns do you see in failures vs successes?
        3. What is the recommended fix?
        4. What additional information would help diagnose further?

        Respond in JSON format with keys: root_cause, confidence, recommended_fix,
        fix_code (if applicable), and additional_info_needed.
        """

        response = self.client.chat.completions.create(
            model="gpt-4",
            messages=[
                {"role": "system", "content": "You are an expert test engineer specializing in diagnosing flaky tests."},
                {"role": "user", "content": prompt}
            ],
            response_format={"type": "json_object"}
        )

        return json.loads(response.choices[0].message.content)

    def suggest_test_improvements(self, test_file_content: str) -> List[Dict]:
        """AI suggestions for test quality improvements"""

        prompt = f"""
        Review this test file and suggest improvements:

        ```python
        {test_file_content}
        ```

        Check for:
        1. Missing assertions
        2. Hardcoded values that could be dynamic
        3. Missing error case testing
        4. Timing issues (sleep, waits)
        5. External dependencies without mocking
        6. Non-deterministic operations

        Provide specific code suggestions in JSON format.
        """

        response = self.client.chat.completions.create(
            model="gpt-4",
            messages=[
                {"role": "system", "content": "You are a senior QA engineer."},
                {"role": "user", "content": prompt}
            ],
            response_format={"type": "json_object"}
        )

        return json.loads(response.choices[0].message.content)
```

## Continuous Maintenance

### Weekly Test Review Checklist (2026)

```markdown
## Weekly Test Health Checklist

### Automated Metrics (Pull from Dashboard)
- [ ] Test execution time trend: _____ (target: < 10 min)
- [ ] Flaky test count: _____ (target: < 3)
- [ ] Mutation score: _____% (target: > 70%)
- [ ] Coverage trend: _____% (target: stable or increasing)
- [ ] CI success rate: _____% (target: > 95%)

### Flaky Test Management
- [ ] Review new flaky tests detected this week
- [ ] Check quarantine age > 30 days
- [ ] Attempt reentry for stable quarantined tests
- [ ] Create tickets for flaky tests needing developer attention

### Test Debt Review
- [ ] Count TODO/FIXME in test files: _____
- [ ] Review skipped tests: _____
- [ ] Identify obsolete tests for removal: _____
- [ ] Check for test files > 500 lines: _____

### Performance
- [ ] Slowest 5 tests this week:
  1. _____ (_____s)
  2. _____ (_____s)
  3. _____ (_____s)
  4. _____ (_____s)
  5. _____ (_____s)
- [ ] Tests added parallelization opportunities: _____

### Documentation
- [ ] Tests lacking docstrings: _____
- [ ] Outdated test documentation: _____
- [ ] New feature test coverage: _____%

### Actions Created This Week
- [ ] Tests fixed: _____
- [ ] Tests quarantined: _____
- [ ] Tests removed: _____
- [ ] New tests added: _____
```

### Automated Maintenance Bot

```yaml
# .github/workflows/test-maintenance.yml
name: Test Maintenance Bot

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday
  workflow_dispatch:

jobs:
  health-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Analyze test health
        run: |
          python scripts/analyze_test_health.py > health_report.json

      - name: Detect new flaky tests
        run: |
          python scripts/detect_flaky.py --since=7days > new_flaky.json
          if [ -s new_flaky.json ]; then
            python scripts/create_flaky_issues.py new_flaky.json
          fi
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Generate quarantine report
        run: |
          python scripts/quarantine_report.py > quarantine_report.md

      - name: Create maintenance issue
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const health = JSON.parse(fs.readFileSync('health_report.json'));
            const quarantine = fs.readFileSync('quarantine_report.md', 'utf8');

            const body = `## Weekly Test Health Report

            ### Metrics
            - Health Score: ${health.health_score}/100
            - Flaky Tests: ${health.flaky_tests.count}
            - Test Duration: ${health.summary.duration_minutes.toFixed(1)}min
            - Coverage: ${health.summary.coverage.toFixed(1)}%

            ### Recommendations
            ${health.recommendations.map(r => `- ${r}`).join('\n')}

            ### Quarantine Status
            ${quarantine}

            _Generated: ${new Date().toISOString()}_
            `;

            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `Test Health Report - Week ${new Date().toISOString().slice(0, 10)}`,
              body: body,
              labels: ['maintenance', 'tests']
            });

      - name: Archive old test results
        run: |
          find test_results/ -mtime +30 -name "*.json" -delete
          echo "Cleaned up test results older than 30 days"
```

## Best Practices (2026)

1. **Zero Flaky Test Policy**: New flaky tests must be fixed or quarantined within 24 hours
2. **ML-Based Detection**: Use machine learning to identify patterns and predict flakiness
3. **Smart Quarantine**: Intelligent graduated re-entry process, not just skip
4. **Health Dashboards**: Real-time visibility into test suite health metrics
5. **AI-Assisted Diagnosis**: Use AI to suggest fixes for failing tests
6. **Test Ownership**: Every test has a clear owner responsible for maintenance
7. **Continuous Refactoring**: Regular test suite optimization sprints
8. **Fail Fast**: Quick feedback loops for test health issues
9. **Data-Driven**: Make decisions based on metrics, not gut feeling
10. **Automation First**: Automate maintenance tasks where possible

## Resources

- [Google Testing Blog: Where do our flaky tests come from?](https://testing.googleblog.com/)
- [Flaky Tests at Google](https://research.google/pubs/pub45852/)
- [pytest-rerunfailures](https://github.com/pytest-dev/pytest-rerunfailures)
- [pytest-flakefinder](https://github.com/dropbox/pytest-flakefinder)
- [Quarantine Pattern](https://martinfowler.com/bliki/Quarantine.html)

---

# Visual Testing Guide

Comprehensive guide to visual regression testing.

## Playwright Visual Testing

### Basic Screenshot Comparison

```javascript
const { test, expect } = require('@playwright/test');

test('homepage visual regression', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveScreenshot('homepage.png', {
    maxDiffPixels: 100,
    threshold: 0.2,
  });
});

test('component visual test', async ({ page }) => {
  await page.goto('/storybook');
  const component = await page.locator('[data-testid="button-primary"]');
  await expect(component).toHaveScreenshot('button-primary.png');
});
```

### Masking Dynamic Content

```javascript
test('dashboard with masked dates', async ({ page }) => {
  await page.goto('/dashboard');
  await expect(page).toHaveScreenshot('dashboard.png', {
    mask: [
      page.locator('.timestamp'),
      page.locator('.user-id'),
    ],
  });
});
```

### Multi-Viewport Testing

```javascript
test.describe('responsive design', () => {
  test.use({ viewport: { width: 1280, height: 720 }});
  test('desktop view', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveScreenshot('homepage-desktop.png');
  });

  test.use({ viewport: { width: 375, height: 667 }});
  test('mobile view', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveScreenshot('homepage-mobile.png');
  });
});
```

## Storybook + Chromatic

### Setup

```bash
npm install --save-dev chromatic
npx chromatic --project-token=<your-token>
```

### CI Integration

```yaml
- name: Publish to Chromatic
  uses: chromaui/action@v1
  with:
    projectToken: ${{ secrets.CHROMATIC_PROJECT_TOKEN }}
    exitZeroOnChanges: true
```

## Percy Integration

```yaml
- name: Percy Visual Testing
  uses: percy/exec-action@v0.3.1
  with:
    command: "npm run test:e2e"
  env:
    PERCY_TOKEN: ${{ secrets.PERCY_TOKEN }}
```

## Applitools

```javascript
const { test, expect } = require('@playwright/test');
const { ClassicRunner, VisualGridRunner, RunnerOptions, Eyes, Target } = require('@applitools/eyes-playwright');

let eyes;

test.beforeEach(async () => {
  eyes = new Eyes(new ClassicRunner());
  await eyes.open({
    appName: 'My App',
    testName: test.info().title,
  });
});

test('visual test with applitools', async ({ page }) => {
  await page.goto('/');
  await eyes.check(Target.window().fully());
});

test.afterEach(async () => {
  await eyes.close();
});
```

## Best Practices

1. **Disable animations** before capturing screenshots
2. **Use deterministic data** (no random timestamps)
3. **Mask dynamic elements** like dates, IDs, usernames
4. **Test critical paths only** - not every component
5. **Review diffs in CI** before merging
