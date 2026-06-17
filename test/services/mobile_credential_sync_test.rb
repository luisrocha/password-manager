require "test_helper"

class MobileCredentialSyncTest < ActiveSupport::TestCase
  ENCRYPTED_PAYLOAD = "-----BEGIN PGP MESSAGE-----\nservice-sync-payload\n-----END PGP MESSAGE-----".freeze

  test "returns encrypted credential payloads" do
    credential = Credential.create!(
      name: "GitHub",
      domain: "github.com",
      category: "login",
      encrypted_secret_payload: ENCRYPTED_PAYLOAD
    )

    result = MobileCredentialSync.call
    payload = result.fetch(:credentials).first

    assert_equal credential.id.to_s, payload.fetch(:id)
    assert_equal "GitHub", payload.fetch(:displayName)
    assert_equal ENCRYPTED_PAYLOAD, payload.fetch(:encryptedSecretPayload)
    assert result.fetch(:syncedAt).present?
  end

  test "reports invalid operation types" do
    result = MobileCredentialSync.call(operations: [
      {
        "id" => "operation_unknown",
        "type" => "unknown",
        "localId" => "credential_local"
      }
    ])

    operation = result.fetch(:operations).first
    assert_equal "failed", operation.fetch(:status)
    assert_equal "invalid_operation_type", operation.fetch(:code)
  end

  test "reports invalid credential payloads" do
    result = MobileCredentialSync.call(operations: [
      {
        "id" => "operation_create",
        "type" => "create",
        "localId" => "credential_local",
        "credential" => {
          "displayName" => "Broken",
          "domain" => "broken.test",
          "category" => "not-a-category",
          "encryptedSecretPayload" => ENCRYPTED_PAYLOAD
        }
      }
    ])

    operation = result.fetch(:operations).first
    assert_equal "failed", operation.fetch(:status)
    assert_equal "invalid_credential", operation.fetch(:code)
    assert_nil Credential.find_by(domain: "broken.test")
  end
end
