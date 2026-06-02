require "test_helper"

class BrowserApiTokenTest < ActiveSupport::TestCase
  setup do
    @previous_token_hashes = ENV[BrowserApiToken::HASHES_ENV_KEY]
  end

  teardown do
    restore_env(BrowserApiToken::HASHES_ENV_KEY, @previous_token_hashes)
  end

  test "accepts a token that matches one configured hash" do
    ENV[BrowserApiToken::HASHES_ENV_KEY] = BrowserApiToken.sha256("browser-static-token")

    assert BrowserApiToken.valid?("browser-static-token")
    assert_not BrowserApiToken.valid?("wrong-token")
  end

  test "accepts any token matching multiple configured hashes" do
    ENV[BrowserApiToken::HASHES_ENV_KEY] = [
      BrowserApiToken.sha256("old-token"),
      BrowserApiToken.sha256("new-token")
    ].join(",")

    assert BrowserApiToken.valid?("old-token")
    assert BrowserApiToken.valid?("new-token")
    assert_not BrowserApiToken.valid?("wrong-token")
  end

  test "rejects tokens when no valid hashes are configured" do
    ENV.delete(BrowserApiToken::HASHES_ENV_KEY)

    assert_not BrowserApiToken.valid?("browser-static-token")
  end

  test "rejects tokens when only invalid hashes are configured" do
    ENV[BrowserApiToken::HASHES_ENV_KEY] = "not-a-sha256-hash"

    assert_not BrowserApiToken.valid?("browser-static-token")
  end

  private

  def restore_env(key, value)
    value.nil? ? ENV.delete(key) : ENV[key] = value
  end
end
