# frozen_string_literal: true

class CredentialSerializer
  def initialize(credential)
    @credential = credential
  end

  def as_json(*)
    {
      id: credential.id.to_s,
      displayName: credential.name,
      domain: credential.domain.to_s,
      encryptedSecretPayload: credential.encrypted_secret_payload
    }
  end

  def sync_json
    as_json.merge(
      category: credential.category,
      updatedAt: credential.updated_at.iso8601
    )
  end

  private

  attr_reader :credential
end
