# frozen_string_literal: true

class VaultSetupToken
  ENV_KEY = 'PASSWORD_MANAGER_SETUP_TOKEN'
  PLACEHOLDER_VALUES = ['', 'replace-with-a-setup-token'].freeze

  def self.required?
    true
  end

  def self.valid?(provided_token)
    expected_token = ENV[ENV_KEY].to_s
    provided_token = provided_token.to_s
    return false if PLACEHOLDER_VALUES.include?(expected_token)
    return false if provided_token.blank?
    return false unless provided_token.bytesize == expected_token.bytesize

    ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
  end

  def self.token_configured?
    !PLACEHOLDER_VALUES.include?(ENV[ENV_KEY].to_s)
  end
end
