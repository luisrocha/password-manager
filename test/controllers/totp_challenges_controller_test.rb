# frozen_string_literal: true

require 'test_helper'

class TotpChallengesControllerTest < ActionDispatch::IntegrationTest
  test 'redirects without a pending totp unlock' do
    get totp_challenge_url

    assert_redirected_to unlock_url
  end

  test 'requires valid totp code after unlock proof' do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    setting = TotpSetting.create!(secret: TotpSetting.generate_secret, enabled_at: Time.current)

    get unlock_url
    post unlock_url, params: unlock_proof_params.except(:setup_token)

    assert_redirected_to totp_challenge_url

    get credentials_url
    assert_redirected_to unlock_url

    post totp_challenge_url, params: { code: '000000' }
    assert_redirected_to totp_challenge_url

    post totp_challenge_url, params: { code: ROTP::TOTP.new(setting.secret).now }
    assert_redirected_to credentials_url
  end

  test 'accepts recovery code once after unlock proof' do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    recovery_codes = TotpSetting.generate_recovery_codes
    setting = TotpSetting.create!(
      secret: TotpSetting.generate_secret,
      enabled_at: Time.current,
      recovery_codes:
    )

    get unlock_url
    post unlock_url, params: unlock_proof_params.except(:setup_token)
    post totp_challenge_url, params: { code: recovery_codes.first }

    assert_redirected_to credentials_url
    assert_equal recovery_codes.count - 1, setting.reload.recovery_codes_remaining

    delete lock_url
    get unlock_url
    post unlock_url, params: unlock_proof_params.except(:setup_token)
    post totp_challenge_url, params: { code: recovery_codes.first }

    assert_redirected_to totp_challenge_url
  end

  test 'remembered client skips totp only after fresh unlock proof' do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    setting = TotpSetting.create!(secret: TotpSetting.generate_secret, enabled_at: Time.current)

    get unlock_url
    post unlock_url, params: unlock_proof_params.except(:setup_token)
    post totp_challenge_url, params: {
      code: ROTP::TOTP.new(setting.secret).now,
      remember_client: '1'
    }

    assert_redirected_to credentials_url
    assert_equal 1, TotpRememberedClient.count

    delete lock_url
    get credentials_url
    assert_redirected_to unlock_url

    get unlock_url
    post unlock_url, params: unlock_proof_params.except(:setup_token)

    assert_redirected_to credentials_url
  end

  test 'expired remembered client still requires totp' do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    setting = TotpSetting.create!(secret: TotpSetting.generate_secret, enabled_at: Time.current)

    get unlock_url
    post unlock_url, params: unlock_proof_params.except(:setup_token)
    post totp_challenge_url, params: {
      code: ROTP::TOTP.new(setting.secret).now,
      remember_client: '1'
    }
    assert_redirected_to credentials_url

    TotpRememberedClient.last.update!(expires_at: 1.second.ago)
    delete lock_url

    get unlock_url
    post unlock_url, params: unlock_proof_params.except(:setup_token)

    assert_redirected_to totp_challenge_url

    post totp_challenge_url, params: { code: ROTP::TOTP.new(setting.secret).now }
    assert_redirected_to credentials_url
  end

  test 'unlock page clears pending totp unlock' do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    setting = TotpSetting.create!(secret: TotpSetting.generate_secret, enabled_at: Time.current)

    get unlock_url
    post unlock_url, params: unlock_proof_params.except(:setup_token)
    assert_redirected_to totp_challenge_url

    get unlock_url
    post totp_challenge_url, params: { code: ROTP::TOTP.new(setting.secret).now }

    assert_redirected_to unlock_url
  end

  test 'expired pending totp unlock redirects to unlock' do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    setting = TotpSetting.create!(secret: TotpSetting.generate_secret, enabled_at: Time.current)

    get unlock_url
    post unlock_url, params: unlock_proof_params.except(:setup_token)
    assert_redirected_to totp_challenge_url

    travel 6.minutes

    post totp_challenge_url, params: { code: ROTP::TOTP.new(setting.secret).now }

    assert_redirected_to unlock_url
  end
end
