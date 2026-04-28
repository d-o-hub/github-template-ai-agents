# C# Pact Quickstart

Using `PactNet`.

## Dependency
```bash
dotnet add package PactNet
```

## Example Consumer Test
```csharp
using PactNet;
using Xunit;

public class MyApiTests
{
    private readonly IPactBuilderV3 pactBuilder;

    public MyApiTests()
    {
        var config = new PactConfig { PactDir = "../../../contracts/pacts" };
        this.pactBuilder = Pact.V3("Consumer", "Provider", config);
    }

    [Fact]
    public async Task GetUser_ReturnsUser()
    {
        this.pactBuilder
            .UponReceiving("a request for a user")
            .Given("user exists")
            .WithRequest(HttpMethod.Get, "/users/123")
            .WillRespondWith()
            .WithStatus(System.Net.HttpStatusCode.OK)
            .WithJsonBody(new { id = "123", name = "John Doe" });

        await this.pactBuilder.VerifyAsync(async ctx =>
        {
            var client = new HttpClient { BaseAddress = ctx.MockServerUri };
            var response = await client.GetAsync("/users/123");
            Assert.Equal(System.Net.HttpStatusCode.OK, response.StatusCode);
        });
    }
}
```
