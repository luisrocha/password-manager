require "test_helper"

class Api::Browser::CredentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_api_token = ENV["PASSWORD_MANAGER_API_TOKEN"]
    ENV["PASSWORD_MANAGER_API_TOKEN"] = nil
    @auth_header = { "Authorization" => "Bearer #{BrowserJwt.issue_encrypted_token[:token]}" }
  end

  teardown do
    ENV["PASSWORD_MANAGER_API_TOKEN"] = @previous_api_token
  end

  test "returns credentials matching request host" do
    matching = Credential.create!(
      name: "GitHub",
      domain: "github.com",
      category: "login",
      username: "alice",
      password: "secret"
    )
    Credential.create!(name: "Mail", domain: "mail.example.com", category: "login", username: "bob", password: "other")

    post "/api/browser/credentials/search",
      params: { origin: "https://github.com", url: "https://github.com/login" },
      headers: @auth_header,
      as: :json

    assert_response :success

    body = response.parsed_body
    assert_equal 1, body.fetch("credentials").size
    assert_equal matching.id.to_s, body.dig("credentials", 0, "id")
    assert_equal "GitHub", body.dig("credentials", 0, "displayName")
    assert_equal "alice", body.dig("credentials", 0, "username")
    assert_equal "secret", body.dig("credentials", 0, "password")
  end

  test "matches parent domains from subdomains" do
    Credential.create!(name: "Main Site", domain: "example.com", category: "login", username: "owner", password: "pw")

    post "/api/browser/credentials/search",
      params: { url: "https://auth.example.com/login" },
      headers: @auth_header,
      as: :json

    assert_response :success
    assert_equal 1, response.parsed_body.fetch("credentials").size
  end

  test "returns multiple credentials for the same domain" do
    first = Credential.create!(name: "GitHub Personal", domain: "github.com", category: "login", username: "alice", password: "secret-1")
    second = Credential.create!(name: "GitHub Work", domain: "github.com", category: "login", username: "alice.work", password: "secret-2")

    post "/api/browser/credentials/search",
      params: { origin: "https://github.com" },
      headers: @auth_header,
      as: :json

    assert_response :success
    ids = response.parsed_body.fetch("credentials").map { |item| item.fetch("id") }
    assert_equal [first.id.to_s, second.id.to_s].sort, ids.sort
  end

  test "returns unauthorized when browser token is missing" do
    post "/api/browser/credentials/search",
      params: { origin: "https://github.com" },
      as: :json

    assert_response :unauthorized
    assert_equal "invalid_token", response.parsed_body["code"]
  end

  test "returns unauthorized when browser token is expired" do
    expired_token = BrowserJwt.issue_encrypted_token(expires_in: -1)[:token]

    post "/api/browser/credentials/search",
      params: { origin: "https://github.com" },
      headers: { "Authorization" => "Bearer #{expired_token}" },
      as: :json

    assert_response :unauthorized
    assert_equal "token_expired", response.parsed_body["code"]
  end

  test "accepts legacy static bearer token when configured" do
    ENV["PASSWORD_MANAGER_API_TOKEN"] = "test-token"
    credential = Credential.create!(name: "GitHub", domain: "github.com", category: "login", username: "alice", password: "secret")

    post "/api/browser/credentials/search",
      params: { origin: "https://github.com" },
      headers: { "Authorization" => "Bearer test-token" },
      as: :json

    assert_response :success
    assert_equal credential.id.to_s, response.parsed_body.dig("credentials", 0, "id")
  end
end
