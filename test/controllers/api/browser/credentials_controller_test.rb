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
    assert_equal "github.com", body.dig("credentials", 0, "domain")
    assert_equal "alice", body.dig("credentials", 0, "username")
    assert_not body.fetch("credentials", []).first.key?("password")
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

  test "supports global search by name, domain, and username" do
    github = Credential.create!(name: "GitHub", domain: "github.com", category: "login", username: "alice", password: "secret-1")
    gitlab = Credential.create!(name: "GitLab", domain: "gitlab.com", category: "login", username: "bob", password: "secret-2")
    gmail = Credential.create!(name: "Mail", domain: "mail.example.com", category: "login", username: "carol@example.com", password: "secret-3")

    post "/api/browser/credentials/search",
      params: { query: "hub" },
      headers: @auth_header,
      as: :json
    assert_response :success
    assert_equal [github.id.to_s], response.parsed_body.fetch("credentials").map { |item| item.fetch("id") }

    post "/api/browser/credentials/search",
      params: { query: "lab.com" },
      headers: @auth_header,
      as: :json
    assert_response :success
    assert_equal [gitlab.id.to_s], response.parsed_body.fetch("credentials").map { |item| item.fetch("id") }

    post "/api/browser/credentials/search",
      params: { query: "carol@" },
      headers: @auth_header,
      as: :json
    assert_response :success
    assert_equal [gmail.id.to_s], response.parsed_body.fetch("credentials").map { |item| item.fetch("id") }
  end

  test "returns no credentials when host and query are both missing" do
    Credential.create!(name: "GitHub", domain: "github.com", category: "login", username: "alice", password: "secret")

    post "/api/browser/credentials/search",
      params: {},
      headers: @auth_header,
      as: :json

    assert_response :success
    assert_empty response.parsed_body.fetch("credentials")
  end

  test "reveals a single credential password on demand" do
    credential = Credential.create!(
      name: "GitHub",
      domain: "github.com",
      category: "login",
      username: "alice",
      password: "secret"
    )

    get "/api/browser/credentials/#{credential.id}",
      headers: @auth_header,
      as: :json

    assert_response :success
    assert_equal credential.id.to_s, response.parsed_body.dig("credential", "id")
    assert_equal "secret", response.parsed_body.dig("credential", "password")
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

  test "rejects static bearer token for credential search" do
    ENV["PASSWORD_MANAGER_API_TOKEN"] = "test-token"

    post "/api/browser/credentials/search",
      params: { origin: "https://github.com" },
      headers: { "Authorization" => "Bearer test-token" },
      as: :json

    assert_response :unauthorized
    assert_equal "invalid_token", response.parsed_body["code"]
  end

  test "rejects static bearer token for credential create" do
    ENV["PASSWORD_MANAGER_API_TOKEN"] = "test-token"

    post "/api/browser/credentials",
      params: {
        origin: "https://github.com",
        title: "GitHub",
        username: "alice@example.com",
        password: "secret-123"
      },
      headers: { "Authorization" => "Bearer test-token" },
      as: :json

    assert_response :unauthorized
    assert_equal "invalid_token", response.parsed_body["code"]
  end

  test "rejects static bearer token for credential update" do
    ENV["PASSWORD_MANAGER_API_TOKEN"] = "test-token"
    credential = Credential.create!(
      name: "GitHub",
      domain: "github.com",
      category: "login",
      username: "alice@example.com",
      password: "secret-123"
    )

    patch "/api/browser/credentials/#{credential.id}",
      params: {
        username: "alice.updated@example.com",
        password: "updated-secret"
      },
      headers: { "Authorization" => "Bearer test-token" },
      as: :json

    assert_response :unauthorized
    assert_equal "invalid_token", response.parsed_body["code"]
  end

  test "rejects static bearer token for credential delete" do
    ENV["PASSWORD_MANAGER_API_TOKEN"] = "test-token"
    credential = Credential.create!(
      name: "GitHub",
      domain: "github.com",
      category: "login",
      username: "alice@example.com",
      password: "secret-123"
    )

    delete "/api/browser/credentials/#{credential.id}",
      headers: { "Authorization" => "Bearer test-token" },
      as: :json

    assert_response :unauthorized
    assert_equal "invalid_token", response.parsed_body["code"]
  end

  test "creates a credential from browser form data" do
    assert_difference("Credential.count", 1) do
      post "/api/browser/credentials",
        params: {
          origin: "https://github.com",
          name: "GitHub Personal",
          title: "GitHub",
          username: "alice@example.com",
          password: "secret-123"
        },
        headers: @auth_header,
        as: :json
    end

    assert_response :created

    credential = Credential.order(:created_at).last
    assert_equal "GitHub Personal", credential.name
    assert_equal "github.com", credential.domain
    assert_equal "alice@example.com", credential.username
    assert_equal "secret-123", credential.password
    assert_equal credential.id.to_s, response.parsed_body.dig("credential", "id")
  end

  test "returns validation error when password is missing during browser create" do
    post "/api/browser/credentials",
      params: {
        origin: "https://github.com",
        username: "alice@example.com"
      },
      headers: @auth_header,
      as: :json

    assert_response :unprocessable_entity
    assert_equal "validation_failed", response.parsed_body["code"]
  end

  test "updates a credential from browser form data" do
    credential = Credential.create!(
      name: "GitHub",
      domain: "github.com",
      category: "login",
      username: "alice@example.com",
      password: "secret-123"
    )

    patch "/api/browser/credentials/#{credential.id}",
      params: {
        name: "GitHub Updated",
        username: "alice.updated@example.com",
        password: "updated-secret"
      },
      headers: @auth_header,
      as: :json

    assert_response :success
    assert_equal "GitHub Updated", credential.reload.name
    assert_equal "alice.updated@example.com", credential.reload.username
    assert_equal "updated-secret", credential.password
    assert_equal credential.id.to_s, response.parsed_body.dig("credential", "id")
  end

  test "returns validation error when password is missing during browser update" do
    credential = Credential.create!(
      name: "GitHub",
      domain: "github.com",
      category: "login",
      username: "alice@example.com",
      password: "secret-123"
    )

    patch "/api/browser/credentials/#{credential.id}",
      params: { username: "alice.updated@example.com", password: "" },
      headers: @auth_header,
      as: :json

    assert_response :unprocessable_entity
    assert_equal "validation_failed", response.parsed_body["code"]
  end

  test "preserves notes when browser update omits notes" do
    credential = Credential.create!(
      name: "GitHub",
      domain: "github.com",
      category: "login",
      username: "alice@example.com",
      password: "secret-123",
      notes: "Keep this note"
    )

    patch "/api/browser/credentials/#{credential.id}",
      params: {
        username: "alice.updated@example.com",
        password: "updated-secret"
      },
      headers: @auth_header,
      as: :json

    assert_response :success
    assert_equal "alice.updated@example.com", credential.reload.username
    assert_equal "Keep this note", credential.notes
  end

  test "deletes a credential from browser edit flow" do
    credential = Credential.create!(
      name: "GitHub",
      domain: "github.com",
      category: "login",
      username: "alice@example.com",
      password: "secret-123"
    )

    assert_difference("Credential.count", -1) do
      delete "/api/browser/credentials/#{credential.id}",
        headers: @auth_header,
        as: :json
    end

    assert_response :success
    assert_equal credential.id.to_s, response.parsed_body.dig("credential", "id")
  end
end
