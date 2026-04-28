#include <pact_ffi.h>
#include <iostream>
#include <cassert>

int main() {
    auto pact_handle = pact_new("Consumer", "Provider");
    auto interaction_handle = pact_new_interaction(pact_handle, "a request for a user");

    pact_upon_receiving(interaction_handle, "a request for a user");
    pact_with_request(interaction_handle, "GET", "/users/123");
    pact_response_status(interaction_handle, 200);
    pact_with_header(interaction_handle, INTERACTION_PART_RESPONSE, "Content-Type", "application/json", 0);
    pact_with_body(interaction_handle, INTERACTION_PART_RESPONSE, "application/json", "{\"id\": \"123\", \"name\": \"John Doe\"}");

    int port = pact_create_mock_server_for_pact(pact_handle, "127.0.0.1:0", false);
    assert(port > 0);

    std::cout << "Mock server started on port: " << port << std::endl;

    // Perform actual HTTP call using a library like libcurl

    int result = pact_mock_server_matched_perfectly(port);
    assert(result == 1);

    pact_write_pact_file(pact_handle, "contracts/pacts", false);
    pact_cleanup_mock_server(port);

    return 0;
}
