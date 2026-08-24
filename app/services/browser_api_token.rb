# frozen_string_literal: true

require 'openssl'

module BrowserApiToken
  HASHES_ENV_KEY = 'PASSWORD_MANAGER_API_TOKEN_SHA256_HASHES'

  module_function

  def valid?(provided_token)
    provided_token = provided_token.to_s
    return false if provided_token.blank?
    return false if configured_hashes.empty?

    provided_hash = sha256(provided_token)
    configured_hashes.any? { |configured_hash| secure_compare(provided_hash, configured_hash) }
  end

  def sha256(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  def configured_hashes
    ENV.fetch(HASHES_ENV_KEY, '')
       .split(',')
       .map { |hash| hash.strip.downcase }
       .grep(/\A[0-9a-f]{64}\z/)
  end

  def secure_compare(provided_value, expected_value)
    return false if provided_value.blank? || expected_value.blank?
    return false unless provided_value.bytesize == expected_value.bytesize

    ActiveSupport::SecurityUtils.secure_compare(provided_value, expected_value)
  end
end
