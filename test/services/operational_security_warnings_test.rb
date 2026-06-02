require "test_helper"

class OperationalSecurityWarningsTest < ActiveSupport::TestCase
  test "reports missing production operational secrets" do
    messages = OperationalSecurityWarnings.messages(env: {})

    assert_includes messages, "SECRET_KEY_BASE is missing or still set to an example placeholder."
    assert_includes messages, "#{VaultSetupToken::ENV_KEY} is missing or still set to an example placeholder."
    assert_includes messages, "#{BrowserApiToken::HASHES_ENV_KEY} is missing or still set to an example placeholder."
  end

  test "reports placeholder production operational secrets" do
    messages = OperationalSecurityWarnings.messages(
      env: {
        "SECRET_KEY_BASE" => "replace-with-a-generated-secret",
        VaultSetupToken::ENV_KEY => "replace-with-a-setup-token",
        BrowserApiToken::HASHES_ENV_KEY => "replace-with-token-sha256-hash"
      }
    )

    assert_equal 3, messages.size
  end

  test "does not report configured production operational secrets" do
    messages = OperationalSecurityWarnings.messages(
      env: {
        "SECRET_KEY_BASE" => "generated-secret-key-base",
        VaultSetupToken::ENV_KEY => "generated-setup-token",
        BrowserApiToken::HASHES_ENV_KEY => BrowserApiToken.sha256("generated-api-token")
      }
    )

    assert_empty messages
  end
end
