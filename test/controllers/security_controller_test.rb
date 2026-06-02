require "test_helper"

class SecurityControllerTest < ActionDispatch::IntegrationTest
  test "requires unlocked vault session" do
    get security_url

    assert_redirected_to unlock_url
  end

  test "renders totp enrollment UI" do
    unlock!

    get security_url

    assert_response :success
    assert_includes response.body, "Two-factor authentication"
    assert_includes response.body, "Enable"
  end

  test "starts and confirms totp enrollment" do
    unlock!

    post totp_setting_url
    assert_redirected_to security_url
    follow_redirect!

    assert_includes response.body, "<svg"
    secret = response.body.match(/[A-Z2-7]{16,}/)[0]
    code = ROTP::TOTP.new(secret).now

    assert_difference("TotpSetting.count", 1) do
      post confirm_totp_setting_url, params: { code: }
    end

    assert_redirected_to security_url
    assert TotpSetting.current.enabled?
    assert_equal TotpSetting::RECOVERY_CODE_COUNT, TotpSetting.current.recovery_codes_remaining
    follow_redirect!
    assert_includes response.body, "Save your recovery codes"
    assert_match(/[A-Z0-9]{5}-[A-Z0-9]{5}/, response.body)

    get security_url
    assert_not_includes response.body, "Save your recovery codes"
  end

  test "rejects invalid totp enrollment code" do
    unlock!
    post totp_setting_url

    assert_no_difference("TotpSetting.count") do
      post confirm_totp_setting_url, params: { code: "000000" }
    end

    assert_redirected_to security_url
  end

  test "disabling totp revokes remembered clients" do
    unlock!
    TotpSetting.create!(secret: TotpSetting.generate_secret, enabled_at: Time.current)
    TotpRememberedClient.issue!

    delete totp_setting_url

    assert_redirected_to security_url
    assert_equal 0, TotpRememberedClient.active.count
  end
end
