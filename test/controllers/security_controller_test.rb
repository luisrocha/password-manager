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
    assert_includes response.body, "Two-factor unlock"
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
  end

  test "rejects invalid totp enrollment code" do
    unlock!
    post totp_setting_url

    assert_no_difference("TotpSetting.count") do
      post confirm_totp_setting_url, params: { code: "000000" }
    end

    assert_redirected_to security_url
  end
end
