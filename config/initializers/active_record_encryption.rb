encryption = Rails.application.config.active_record.encryption

encryption.primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].presence || encryption.primary_key
encryption.deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"].presence || encryption.deterministic_key
encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"].presence || encryption.key_derivation_salt

if encryption.primary_key.blank?
  secret = Rails.application.secret_key_base || "development-secret-key-base"
  key_generator = ActiveSupport::KeyGenerator.new(secret, iterations: 1_000)

  encryption.primary_key =
    key_generator.generate_key("active_record_encryption.primary_key", 32)
  encryption.deterministic_key =
    key_generator.generate_key("active_record_encryption.deterministic_key", 32)
  encryption.key_derivation_salt =
    key_generator.generate_key("active_record_encryption.key_derivation_salt", 32)
end
