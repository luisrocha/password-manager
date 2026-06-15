class MobileVaultPairing
  CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".freeze
  CODE_LENGTH = 8
  EXPIRES_IN = 5.minutes
  CACHE_KEY_PREFIX = "mobile_vault_pairing"

  class CodeCollisionError < StandardError; end

  def self.create!(encrypted_vault_backup)
    code = generate_available_code
    Rails.cache.write(cache_key(code), encrypted_vault_backup, expires_in: EXPIRES_IN)

    {
      code: display_code(code),
      expires_in_seconds: EXPIRES_IN.to_i
    }
  end

  def self.redeem(code)
    normalized_code = normalize_code(code)
    return if normalized_code.blank?

    key = cache_key(normalized_code)
    encrypted_vault_backup = Rails.cache.read(key)
    Rails.cache.delete(key) if encrypted_vault_backup.present?

    encrypted_vault_backup
  end

  def self.cache_key(code)
    "#{CACHE_KEY_PREFIX}:#{normalize_code(code)}"
  end

  def self.normalize_code(code)
    code.to_s.upcase.gsub(/[^A-Z0-9]/, "")
  end

  def self.display_code(code)
    normalize_code(code).scan(/.{1,4}/).join("-")
  end

  def self.generate_available_code
    10.times do
      code = Array.new(CODE_LENGTH) { CODE_ALPHABET[SecureRandom.random_number(CODE_ALPHABET.length)] }.join
      return code unless Rails.cache.exist?(cache_key(code))
    end

    raise CodeCollisionError, "Could not create a unique mobile pairing code"
  end

  private_class_method :generate_available_code
end
