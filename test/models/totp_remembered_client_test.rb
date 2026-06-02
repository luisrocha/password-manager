require "test_helper"

class TotpRememberedClientTest < ActiveSupport::TestCase
  test "issues only a digest and validates active token" do
    token = TotpRememberedClient.issue!
    client = TotpRememberedClient.first

    assert token.present?
    assert_not_equal token, client.token_digest
    assert TotpRememberedClient.valid_token?(token)
    assert client.reload.last_used_at.present?
  end

  test "rejects expired and revoked tokens" do
    expired_token = TotpRememberedClient.issue!
    TotpRememberedClient.last.update!(expires_at: 1.second.ago)

    revoked_token = TotpRememberedClient.issue!
    TotpRememberedClient.last.update!(revoked_at: Time.current)

    assert_not TotpRememberedClient.valid_token?(expired_token)
    assert_not TotpRememberedClient.valid_token?(revoked_token)
  end

  test "revokes all active tokens" do
    2.times { TotpRememberedClient.issue! }

    TotpRememberedClient.revoke_all!

    assert_equal 0, TotpRememberedClient.active.count
  end
end
