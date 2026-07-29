class TotpSetting < ApplicationRecord
  ISSUER = "Password Manager"
  ACCOUNT_NAME = "Vault"
  RECOVERY_CODE_COUNT = 10
  RECOVERY_CODE_BYTES = 10

  validates :secret, presence: true
  validate :only_one_totp_setting, on: :create

  def self.current
    order(:created_at).first
  end

  def self.enabled?
    current&.enabled?
  end

  def self.valid_second_factor_code?(code)
    setting = current
    return false if setting.blank?

    setting.verify(code) || setting.consume_recovery_code(code)
  end

  def self.generate_secret
    ROTP::Base32.random_base32
  end

  def self.generate_recovery_codes
    Array.new(RECOVERY_CODE_COUNT) do
      SecureRandom.alphanumeric(RECOVERY_CODE_BYTES).upcase.scan(/.{1,5}/).join("-")
    end
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

  def recovery_codes=(codes)
    self.recovery_code_digests = codes.map { |code| recovery_code_digest(code) }.to_json
  end

  def recovery_codes_remaining
    recovery_code_digest_list.count
  end

  def consume_recovery_code(code)
    digest = recovery_code_digest(code)
    digests = recovery_code_digest_list
    matching_digest = digests.find { |stored_digest| secure_compare(stored_digest, digest) }
    return false if matching_digest.blank?

    digests.delete(matching_digest)
    self.recovery_code_digests = digests.to_json
    save!
  end

  private

  def totp
    ROTP::TOTP.new(secret, issuer: ISSUER)
  end

  def normalized_code(code)
    code.to_s.gsub(/\s+/, "")
  end

  def normalized_recovery_code(code)
    code.to_s.gsub(/[^A-Za-z0-9]/, "").upcase
  end

  def recovery_code_digest(code)
    OpenSSL::Digest::SHA256.hexdigest(normalized_recovery_code(code))
  end

  def recovery_code_digest_list
    JSON.parse(recovery_code_digests.presence || "[]")
  rescue JSON::ParserError
    []
  end

  def secure_compare(a, b)
    ActiveSupport::SecurityUtils.secure_compare(a, b)
  end

  def only_one_totp_setting
    errors.add(:base, "TOTP is already configured") if self.class.exists?
  end
end
