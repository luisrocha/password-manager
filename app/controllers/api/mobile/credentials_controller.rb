class Api::Mobile::CredentialsController < Api::Mobile::BaseController
  def sync
    render json: {
      credentials: Credential.sorted.map { |credential| credential_payload(credential) },
      syncedAt: Time.current.iso8601
    }
  end

  private

  def credential_payload(credential)
    {
      id: credential.id.to_s,
      displayName: credential.name,
      domain: credential.domain.to_s,
      category: credential.category,
      encryptedSecretPayload: credential.encrypted_secret_payload,
      updatedAt: credential.updated_at.iso8601
    }
  end
end
