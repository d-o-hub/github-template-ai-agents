use pact_consumer::prelude::*;
use pact_consumer::*;

#[tokio::test]
async fn test_get_user() {
    let pact = PactBuilder::new("Consumer", "Provider")
        .interaction("a request for a user", |i| {
            i.request.path("/users/123");
            i.response
                .status(200)
                .header("Content-Type", "application/json")
                .json_body(json_pattern!({
                    "id": "123",
                    "name": "John Doe"
                }));
        })
        .build();

    for interaction in pact.interactions() {
        let mock_server = interaction.create_mock_server().await;
        let client = reqwest::Client::new();
        let res = client.get(&format!("{}/users/123", mock_server.url()))
            .send().await.unwrap();

        assert_eq!(res.status(), 200);
    }
}
