# frozen_string_literal: true

module OperationalSecurityWarnings
  SECRET_PLACEHOLDERS = {
    'SECRET_KEY_BASE' => ['replace-with-a-generated-secret'],
    VaultSetupToken::ENV_KEY => VaultSetupToken::PLACEHOLDER_VALUES,
    BrowserApiToken::HASHES_ENV_KEY => ['replace-with-token-sha256-hash']
  }.freeze

  module_function

  def messages(env: ENV)
    SECRET_PLACEHOLDERS.filter_map do |key, placeholders|
      value = env[key].to_s
      next if value.present? && placeholders.exclude?(value)

      "#{key} is missing or still set to an example placeholder."
    end
  end
end
