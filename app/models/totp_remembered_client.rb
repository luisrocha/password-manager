# frozen_string_literal: true

class TotpRememberedClient < ApplicationRecord
  TOKEN_BYTES = 32
  TTL = 24.hours

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where('expires_at > ?', Time.current) }

  def self.issue!
    token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
    create!(
      token_digest: digest(token),
      expires_at: TTL.from_now
    )

    token
  end

  def self.valid_token?(token)
    return false if token.blank?

    client = active.find_by(token_digest: digest(token))
    return false if client.blank?

    client.update!(last_used_at: Time.current)
    true
  end

  def self.revoke_all!
    where(revoked_at: nil).update_all(revoked_at: Time.current, updated_at: Time.current)
  end

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end
end
