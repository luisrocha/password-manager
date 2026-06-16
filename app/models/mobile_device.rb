class MobileDevice < ApplicationRecord
  TOKEN_BYTES = 32

  validates :name, presence: true, length: { maximum: 120 }
  validates :token_digest, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil) }
  scope :sorted, -> { order(Arel.sql("revoked_at IS NOT NULL"), :name, :created_at) }

  def self.issue!(name: "Mobile app")
    token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
    device = create!(
      name: name.to_s.strip.presence || "Mobile app",
      token_digest: digest(token)
    )

    [device, token]
  end

  def self.authenticate(token)
    return if token.blank?

    device = active.find_by(token_digest: digest(token))
    return if device.blank?

    device.update!(last_used_at: Time.current)
    device
  end

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
