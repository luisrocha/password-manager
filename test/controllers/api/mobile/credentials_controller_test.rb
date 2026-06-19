require "test_helper"

class Api::Mobile::CredentialsControllerTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  ENCRYPTED_PAYLOAD = "-----BEGIN PGP MESSAGE-----\nmobile-sync-payload\n-----END PGP MESSAGE-----".freeze
  UPDATED_PAYLOAD = "-----BEGIN PGP MESSAGE-----\nupdated-mobile-sync-payload\n-----END PGP MESSAGE-----".freeze
  SIGNING_KEY = VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY

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
    register_vault_signing_key!

    get api_mobile_credentials_sync_url,
      headers: mobile_sync_headers(token, method: "GET", path: api_mobile_credentials_sync_path),
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

  test "rejects read sync without a vault signature" do
    _device, token = MobileDevice.issue!(name: "Luis Pixel")
    register_vault_signing_key!

    get api_mobile_credentials_sync_url,
      headers: { "Authorization" => "Bearer #{token}" },
      as: :json

    assert_response :unauthorized
    assert_equal "invalid_mobile_sync_signature", response.parsed_body.fetch("code")
  end

  test "creates credentials from mobile pending operations" do
    _device, token = MobileDevice.issue!(name: "Luis Pixel")
    params = {
      operations: [
        {
          id: "operation_create",
          type: "create",
          localId: "credential_local",
          serverId: nil,
          credential: {
            displayName: "Mobile item",
            domain: "mobile.test",
            category: "login",
            encryptedSecretPayload: ENCRYPTED_PAYLOAD
          }
        }
      ]
    }

    assert_broadcasts Credential.broadcast_stream_name, 1 do
      post api_mobile_credentials_sync_url,
        params: params.to_json,
        headers: mobile_sync_headers(
          token,
          params:,
          method: "POST",
          path: api_mobile_credentials_sync_path
        )
    end

    assert_response :success
    operation = response.parsed_body.fetch("operations").first
    credential = Credential.find_by!(domain: "mobile.test")
    assert_equal "confirmed", operation.fetch("status")
    assert_equal "credential_local", operation.fetch("localId")
    assert_equal credential.id.to_s, operation.fetch("serverId")
    assert_equal "Mobile item", credential.name
    assert_equal ENCRYPTED_PAYLOAD, credential.encrypted_secret_payload
    assert_includes response.parsed_body.fetch("credentials").map { |item| item.fetch("id") }, credential.id.to_s
  end

  test "reuses credentials for retried mobile create operations" do
    _device, token = MobileDevice.issue!(name: "Luis Pixel")
    operation = {
      id: "operation_create",
      type: "create",
      localId: "credential_local",
      serverId: nil,
      credential: {
        displayName: "Mobile item",
        domain: "mobile.test",
        category: "login",
        encryptedSecretPayload: ENCRYPTED_PAYLOAD
      }
    }

    2.times do
      params = { operations: [operation] }

      post api_mobile_credentials_sync_url,
        params: params.to_json,
        headers: mobile_sync_headers(
          token,
          params:,
          method: "POST",
          path: api_mobile_credentials_sync_path
        )

      assert_response :success
      assert_equal "confirmed", response.parsed_body.fetch("operations").first.fetch("status")
    end

    credentials = Credential.where(client_uid: "credential_local")
    assert_equal 1, credentials.count
    assert_equal 1, Credential.where(domain: "mobile.test").count
  end

  test "updates credentials from mobile pending operations" do
    credential = Credential.create!(
      name: "Old",
      domain: "old.test",
      category: "login",
      encrypted_secret_payload: ENCRYPTED_PAYLOAD
    )
    _device, token = MobileDevice.issue!(name: "Luis Pixel")
    params = {
      operations: [
        {
          id: "operation_update",
          type: "update",
          localId: credential.id.to_s,
          serverId: credential.id.to_s,
          baseUpdatedAt: credential.updated_at.iso8601,
          credential: {
            displayName: "Updated",
            domain: "updated.test",
            category: "server",
            encryptedSecretPayload: UPDATED_PAYLOAD
          }
        }
      ]
    }

    post api_mobile_credentials_sync_url,
      params: params.to_json,
      headers: mobile_sync_headers(
        token,
        params:,
        method: "POST",
        path: api_mobile_credentials_sync_path
      )

    assert_response :success
    operation = response.parsed_body.fetch("operations").first
    credential.reload
    assert_equal "confirmed", operation.fetch("status")
    assert_equal credential.id.to_s, operation.fetch("serverId")
    assert_equal "Updated", credential.name
    assert_equal "updated.test", credential.domain
    assert_equal "server", credential.category
    assert_equal UPDATED_PAYLOAD, credential.encrypted_secret_payload
  end

  test "deletes credentials from mobile pending operations" do
    credential = Credential.create!(
      name: "Delete me",
      domain: "delete.test",
      category: "login",
      encrypted_secret_payload: ENCRYPTED_PAYLOAD
    )
    _device, token = MobileDevice.issue!(name: "Luis Pixel")
    params = {
      operations: [
        {
          id: "operation_delete",
          type: "delete",
          localId: credential.id.to_s,
          serverId: credential.id.to_s,
          baseUpdatedAt: credential.updated_at.iso8601
        }
      ]
    }

    post api_mobile_credentials_sync_url,
      params: params.to_json,
      headers: mobile_sync_headers(
        token,
        params:,
        method: "POST",
        path: api_mobile_credentials_sync_path
      )

    assert_response :success
    operation = response.parsed_body.fetch("operations").first
    assert_equal "confirmed", operation.fetch("status")
    assert_nil Credential.find_by(id: credential.id)
    assert_not_includes response.parsed_body.fetch("credentials").map { |item| item.fetch("id") }, credential.id.to_s
  end

  test "returns conflicts for stale mobile updates" do
    credential = Credential.create!(
      name: "Server value",
      domain: "server.test",
      category: "login",
      encrypted_secret_payload: ENCRYPTED_PAYLOAD
    )
    _device, token = MobileDevice.issue!(name: "Luis Pixel")
    params = {
      operations: [
        {
          id: "operation_update",
          type: "update",
          localId: credential.id.to_s,
          serverId: credential.id.to_s,
          baseUpdatedAt: 1.day.ago.iso8601,
          credential: {
            displayName: "Stale mobile value",
            domain: "mobile.test",
            category: "login",
            encryptedSecretPayload: UPDATED_PAYLOAD
          }
        }
      ]
    }

    post api_mobile_credentials_sync_url,
      params: params.to_json,
      headers: mobile_sync_headers(
        token,
        params:,
        method: "POST",
        path: api_mobile_credentials_sync_path
      )

    assert_response :success
    operation = response.parsed_body.fetch("operations").first
    assert_equal "conflict", operation.fetch("status")
    assert_equal "Server value", credential.reload.name
    assert_equal ENCRYPTED_PAYLOAD, credential.encrypted_secret_payload
  end

  test "rejects mobile write sync without a vault signature" do
    _device, token = MobileDevice.issue!(name: "Luis Pixel")
    register_vault_signing_key!

    post api_mobile_credentials_sync_url,
      params: { operations: [] },
      headers: { "Authorization" => "Bearer #{token}" },
      as: :json

    assert_response :unauthorized
    assert_equal "invalid_mobile_sync_signature", response.parsed_body.fetch("code")
  end

  test "rejects mobile write sync with a mismatched signing key" do
    _device, token = MobileDevice.issue!(name: "Luis Pixel")
    register_vault_signing_key!
    other_key = OpenSSL::PKey::EC.generate("prime256v1")
    params = { operations: [] }

    post api_mobile_credentials_sync_url,
      params: params.to_json,
      headers: mobile_sync_headers(
        token,
        params:,
        method: "POST",
        path: api_mobile_credentials_sync_path,
        signing_key: other_key
      )

    assert_response :unauthorized
    assert_equal "invalid_mobile_sync_signature", response.parsed_body.fetch("code")
  end

  private

  def register_vault_signing_key!
    VaultSigningKey.find_or_create_by!(
      public_key_spki: Base64.strict_encode64(SIGNING_KEY.public_to_der)
    )
  end

  def mobile_sync_headers(token, method:, path:, params: nil, signing_key: SIGNING_KEY)
    register_vault_signing_key!

    serialized_body = params&.to_json.to_s
    challenge =
      "#{Api::Mobile::CredentialsController::MOBILE_SYNC_SIGNATURE_PREFIX}#{method}:#{path}:#{serialized_body}"

    {
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json",
      "X-Mobile-Sync-Signature" => Base64.strict_encode64(
        signing_key.sign(OpenSSL::Digest::SHA256.new, challenge)
      ),
      "X-Mobile-Sync-Signing-Key" => Base64.strict_encode64(signing_key.public_to_der)
    }
  end

  def assert_no_plaintext_secret_keys(payload)
    assert_not payload.key?("username")
    assert_not payload.key?("password")
    assert_not payload.key?("notes")
  end
end
