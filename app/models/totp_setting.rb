class TotpSetting < ApplicationRecord
  ISSUER = "Password Manager"
  ACCOUNT_NAME = "Vault"

  validates :secret, presence: true
  validate :only_one_totp_setting, on: :create

  def self.current
    order(:created_at).first
  end

  def self.enabled?
    current&.enabled?
  end

  def self.generate_secret
    ROTP::Base32.random_base32
  end

  def enabled?
    enabled_at.present?
  end

  def provisioning_uri
    totp.provisioning_uri(ACCOUNT_NAME)
  end

  def verify(code)
    totp.verify(normalized_code(code), drift_behind: 30, drift_ahead: 30).present?
  end

  private

  def totp
    ROTP::TOTP.new(secret, issuer: ISSUER)
  end

  def normalized_code(code)
    code.to_s.gsub(/\s+/, "")
  end

  def only_one_totp_setting
    errors.add(:base, "TOTP is already configured") if self.class.exists?
  end
end
