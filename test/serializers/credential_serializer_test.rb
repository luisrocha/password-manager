require "test_helper"

class CredentialSerializerTest < ActiveSupport::TestCase
  ENCRYPTED_PAYLOAD = "-----BEGIN PGP MESSAGE-----\nserializer-payload\n-----END PGP MESSAGE-----".freeze

  test "as_json returns the browser-safe encrypted payload shape" do
    credential = credential_record

    payload = CredentialSerializer.new(credential).as_json

    assert_equal credential.id.to_s, payload.fetch(:id)
    assert_equal "GitHub", payload.fetch(:displayName)
    assert_equal "github.com", payload.fetch(:domain)
    assert_equal ENCRYPTED_PAYLOAD, payload.fetch(:encryptedSecretPayload)
    assert_not payload.key?(:category)
    assert_not payload.key?(:updatedAt)
  end

  test "sync_json includes mobile sync metadata" do
    credential = credential_record

    payload = CredentialSerializer.new(credential).sync_json

    assert_equal "login", payload.fetch(:category)
    assert_equal credential.updated_at.iso8601, payload.fetch(:updatedAt)
  end

  private

  def credential_record
    Credential.create!(
      name: "GitHub",
      domain: "github.com",
      category: "login",
      encrypted_secret_payload: ENCRYPTED_PAYLOAD
    )
  end
end
