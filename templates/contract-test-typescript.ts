import { Pact } from '@pact-foundation/pact';
import path from 'path';

const provider = new Pact({
  consumer: 'Consumer',
  provider: 'Provider',
  port: 1234,
  dir: path.resolve(process.cwd(), 'contracts/pacts'),
});

describe('API Pact test', () => {
  before(() => provider.setup());
  after(() => provider.finalize());

  it('validates user data', async () => {
    await provider.addInteraction({
      state: 'user exists',
      uponReceiving: 'a request for a user',
      withRequest: {
        method: 'GET',
        path: '/users/123',
      },
      willRespondWith: {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: {
          id: '123',
          name: 'John Doe',
        },
      },
    });

    // Run actual code here

    await provider.verify();
  });
});
