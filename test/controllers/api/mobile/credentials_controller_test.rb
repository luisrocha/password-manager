require "test_helper"

class Api::Mobile::CredentialsControllerTest < ActionDispatch::IntegrationTest
  ENCRYPTED_PAYLOAD = "-----BEGIN PGP MESSAGE-----\nmobile-sync-payload\n-----END PGP MESSAGE-----".freeze
  UPDATED_PAYLOAD = "-----BEGIN PGP MESSAGE-----\nupdated-mobile-sync-payload\n-----END PGP MESSAGE-----".freeze

  test "syncs all encrypted credentials with an active mobile device token" do
    first = Credential.create!(
      name: "GitHub",
      domain: "github.com",
      category: "login",
      encrypted_secret_payload: ENCRYPTED_PAYLOAD
    )
    second = Credential.create!(
      name: "Server",
      domain: "server.local",
      category: "server",
      encrypted_secret_payload: UPDATED_PAYLOAD
    )
    device, token = MobileDevice.issue!(name: "Luis Pixel")

    get api_mobile_credentials_sync_url,
      headers: { "Authorization" => "Bearer #{token}" },
      as: :json

    assert_response :success
    credentials = response.parsed_body.fetch("credentials")
    assert_equal [first.id.to_s, second.id.to_s].sort, credentials.map { |item| item.fetch("id") }.sort
    assert_equal ["GitHub", "Server"], credentials.map { |item| item.fetch("displayName") }.sort
    assert_equal ["login", "server"], credentials.map { |item| item.fetch("category") }.sort
    assert_equal [ENCRYPTED_PAYLOAD, UPDATED_PAYLOAD].sort, credentials.map { |item| item.fetch("encryptedSecretPayload") }.sort
    assert credentials.all? { |item| item.fetch("updatedAt").present? }
    assert response.parsed_body.fetch("syncedAt").present?
    assert device.reload.last_used_at.present?
    credentials.each { |credential| assert_no_plaintext_secret_keys(credential) }
  end

  test "rejects missing mobile device tokens" do
    get api_mobile_credentials_sync_url, as: :json

    assert_response :unauthorized
    assert_equal "invalid_mobile_device_token", response.parsed_body.fetch("code")
  end

  test "rejects revoked mobile device tokens" do
    device, token = MobileDevice.issue!(name: "Luis Pixel")
    device.revoke!

    get api_mobile_credentials_sync_url,
      headers: { "Authorization" => "Bearer #{token}" },
      as: :json

    assert_response :unauthorized
    assert_equal "invalid_mobile_device_token", response.parsed_body.fetch("code")
  end

  private

  def assert_no_plaintext_secret_keys(payload)
    assert_not payload.key?("username")
    assert_not payload.key?("password")
    assert_not payload.key?("notes")
  end
end
