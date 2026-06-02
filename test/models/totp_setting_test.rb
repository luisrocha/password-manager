require "test_helper"

class TotpSettingTest < ActiveSupport::TestCase
  test "generates and verifies current totp codes" do
    setting = TotpSetting.new(secret: TotpSetting.generate_secret)

    assert setting.verify(ROTP::TOTP.new(setting.secret).now)
    assert_not setting.verify("000000")
  end

  test "tracks enabled state" do
    setting = TotpSetting.new(secret: TotpSetting.generate_secret)

    assert_not setting.enabled?

    setting.enabled_at = Time.current

    assert setting.enabled?
  end

  test "allows only one configured setting" do
    TotpSetting.create!(secret: TotpSetting.generate_secret, enabled_at: Time.current)
    another_setting = TotpSetting.new(secret: TotpSetting.generate_secret, enabled_at: Time.current)

    assert_not another_setting.valid?
    assert_includes another_setting.errors[:base], "TOTP is already configured"
  end
end
