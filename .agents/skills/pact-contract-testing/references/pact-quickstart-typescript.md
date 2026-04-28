# TypeScript Pact Quickstart

Using `@pact-foundation/pact`.

## Dependency
```bash
npm install --save-dev @pact-foundation/pact
```

## Example Consumer Test
```typescript
import { Pact } from '@pact-foundation/pact';
import path from 'path';

const provider = new Pact({
  consumer: 'UserWeb',
  provider: 'UserService',
  port: 1234,
  log: path.resolve(process.cwd(), 'logs', 'pact.log'),
  dir: path.resolve(process.cwd(), 'contracts/pacts'),
});

describe('User API', () => {
  before(() => provider.setup());
  after(() => provider.finalize());

  it('gets a user by ID', async () => {
    await provider.addInteraction({
      state: 'user 1 exists',
      uponReceiving: 'a request for user 1',
      withRequest: {
        method: 'GET',
        path: '/users/1',
      },
      willRespondWith: {
        status: 200,
        body: {
          id: '1',
          name: 'Alice',
        },
      },
    });

    // Call actual client code here
    // const result = await userService.getUser(1);
    // expect(result.name).to.equal('Alice');

    await provider.verify();
  });
});
```
