# Rust Pact Quickstart

Using `pact_consumer` crate.

## Dependency
```toml
[dev-dependencies]
pact_consumer = "0.11.0"
tokio = { version = "1.0", features = ["full"] }
```

## Example Consumer Test
```rust
use pact_consumer::prelude::*;
use pact_consumer::*;

#[tokio::test]
async fn test_get_user() {
    let pact = PactBuilder::new("UserConsumer", "UserService")
        .interaction("a request for user 1", |i| {
            i.request.path("/users/1");
            i.response
                .status(200)
                .json_body(json_pattern!({
                    "id": "1",
                    "name": "Alice"
                }));
        })
        .build();

    for interaction in pact.interactions() {
        let mock_server = interaction.create_mock_server().await;
        let client = reqwest::Client::new();
        let res = client.get(&format!("{}/users/1", mock_server.url()))
            .send().await.unwrap();

        assert_eq!(res.status(), 200);
    }
}
```
