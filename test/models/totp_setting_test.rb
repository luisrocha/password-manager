# frozen_string_literal: true

require 'test_helper'

class TotpSettingTest < ActiveSupport::TestCase
  test 'generates and verifies current totp codes' do
    setting = TotpSetting.new(secret: TotpSetting.generate_secret)

    assert setting.verify(ROTP::TOTP.new(setting.secret).now)
    assert_not setting.verify('000000')
  end

  test 'tracks enabled state' do
    setting = TotpSetting.new(secret: TotpSetting.generate_secret)

    assert_not setting.enabled?

    setting.enabled_at = Time.current

    assert setting.enabled?
  end

  test 'allows only one configured setting' do
    TotpSetting.create!(secret: TotpSetting.generate_secret, enabled_at: Time.current)
    another_setting = TotpSetting.new(secret: TotpSetting.generate_secret, enabled_at: Time.current)

    assert_not another_setting.valid?
    assert_includes another_setting.errors[:base], 'TOTP is already configured'
  end

  test 'generates recovery codes' do
    codes = TotpSetting.generate_recovery_codes

    assert_equal TotpSetting::RECOVERY_CODE_COUNT, codes.count
    assert(codes.all? { |code| code.match?(/\A[A-Z0-9]{5}-[A-Z0-9]{5}\z/) })
  end

  test 'stores only recovery code digests and consumes each code once' do
    codes = TotpSetting.generate_recovery_codes
    setting = TotpSetting.create!(
      secret: TotpSetting.generate_secret,
      enabled_at: Time.current,
      recovery_codes: codes
    )

    assert_equal codes.count, setting.recovery_codes_remaining
    assert_not_includes setting.recovery_code_digests, codes.first
    assert setting.consume_recovery_code(codes.first.downcase.delete('-'))
    assert_equal codes.count - 1, setting.reload.recovery_codes_remaining
    assert_not setting.consume_recovery_code(codes.first)
  end
end
