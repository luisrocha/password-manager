# frozen_string_literal: true

require 'test_helper'

class Api::Browser::AuthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_api_token_hashes = ENV.fetch('PASSWORD_MANAGER_API_TOKEN_SHA256_HASHES', nil)
    ENV['PASSWORD_MANAGER_API_TOKEN_SHA256_HASHES'] = BrowserApiToken.sha256('browser-static-token')
    @auth_header = { 'Authorization' => 'Bearer browser-static-token' }
    Rails.cache.clear
  end

  teardown do
    restore_env('PASSWORD_MANAGER_API_TOKEN_SHA256_HASHES', @previous_api_token_hashes)
    Rails.cache.clear
  end

  test 'issues an api unlock challenge' do
    post '/api/browser/auth/unlock', headers: @auth_header, as: :json

    assert_response :success
    assert response.parsed_body['challengeId'].present?
    assert response.parsed_body['challenge'].present?
    assert_nil response.parsed_body['token']
  end

  test 'returns encrypted jwt token for valid signed challenge' do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )

    post_signed_unlock

    assert_response :success
    assert response.parsed_body['token'].present?
    assert response.parsed_body['expiresAt'].present?
    assert_equal 'Bearer', response.parsed_body['tokenType']
  end

  test 'requires totp after valid signed challenge when two-factor is enabled' do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    TotpSetting.create!(secret: TotpSetting.generate_secret, enabled_at: Time.current)

    post_signed_unlock

    assert_response :accepted
    assert_equal true, response.parsed_body['requiresTotp']
    assert response.parsed_body['totpChallengeId'].present?
    assert_nil response.parsed_body['token']
  end

  test 'returns encrypted jwt token for valid api totp challenge' do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    setting = TotpSetting.create!(secret: TotpSetting.generate_secret, enabled_at: Time.current)
    post_signed_unlock
    totp_challenge_id = response.parsed_body.fetch('totpChallengeId')

    post '/api/browser/auth/unlock',
         params: {
           totpChallengeId: totp_challenge_id,
           totpCode: ROTP::TOTP.new(setting.secret).now
         },
         headers: @auth_header,
         as: :json

    assert_response :success
    assert response.parsed_body['token'].present?
    assert_nil response.parsed_body['totpRememberedClientToken']
  end

  test 'returns remembered client token when requested after valid api totp challenge' do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    setting = TotpSetting.create!(secret: TotpSetting.generate_secret, enabled_at: Time.current)
    post_signed_unlock

    post '/api/browser/auth/unlock',
         params: {
           totpChallengeId: response.parsed_body.fetch('totpChallengeId'),
           totpCode: ROTP::TOTP.new(setting.secret).now,
           rememberClient: true
         },
         headers: @auth_header,
         as: :json

    assert_response :success
    assert response.parsed_body['token'].present?
    assert response.parsed_body['totpRememberedClientToken'].present?
    assert_equal 1, TotpRememberedClient.count
  end

  test 'remembered client token skips only totp after fresh api unlock proof' do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    setting = TotpSetting.create!(secret: TotpSetting.generate_secret, enabled_at: Time.current)
    post_signed_unlock
    post '/api/browser/auth/unlock',
         params: {
           totpChallengeId: response.parsed_body.fetch('totpChallengeId'),
           totpCode: ROTP::TOTP.new(setting.secret).now,
           rememberClient: true
         },
         headers: @auth_header,
         as: :json
    remembered_client_token = response.parsed_body.fetch('totpRememberedClientToken')

    post '/api/browser/auth/unlock',
         params: { totpRememberedClientToken: remembered_client_token },
         headers: @auth_header,
         as: :json
    assert_response :success
    assert response.parsed_body['challengeId'].present?
    assert_nil response.parsed_body['token']

    post_signed_unlock(totpRememberedClientToken: remembered_client_token)

    assert_response :success
    assert response.parsed_body['token'].present?
    assert_nil response.parsed_body['totpChallengeId']
  end

  test 'expired remembered client token does not skip api totp' do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    TotpSetting.create!(secret: TotpSetting.generate_secret, enabled_at: Time.current)
    remembered_client_token = TotpRememberedClient.issue!
    TotpRememberedClient.last.update!(expires_at: 1.second.ago)

    post_signed_unlock(totpRememberedClientToken: remembered_client_token)

    assert_response :accepted
    assert_equal true, response.parsed_body['requiresTotp']
  end

  test 'api totp challenge accepts recovery code once' do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    recovery_codes = TotpSetting.generate_recovery_codes
    setting = TotpSetting.create!(
      secret: TotpSetting.generate_secret,
      enabled_at: Time.current,
      recovery_codes:
    )
    post_signed_unlock

    post '/api/browser/auth/unlock',
         params: {
           totpChallengeId: response.parsed_body.fetch('totpChallengeId'),
           totpCode: recovery_codes.first
         },
         headers: @auth_header,
         as: :json

    assert_response :success
    assert response.parsed_body['token'].present?
    assert_equal recovery_codes.count - 1, setting.reload.recovery_codes_remaining

    post_signed_unlock
    post '/api/browser/auth/unlock',
         params: {
           totpChallengeId: response.parsed_body.fetch('totpChallengeId'),
           totpCode: recovery_codes.first
         },
         headers: @auth_header,
         as: :json

    assert_response :unauthorized
    assert_equal 'invalid_totp_code', response.parsed_body['code']
  end

  test 'rejects expired api totp challenge' do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    setting = TotpSetting.create!(secret: TotpSetting.generate_secret, enabled_at: Time.current)
    post_signed_unlock
    totp_challenge_id = response.parsed_body.fetch('totpChallengeId')

    travel 6.minutes

    post '/api/browser/auth/unlock',
         params: {
           totpChallengeId: totp_challenge_id,
           totpCode: ROTP::TOTP.new(setting.secret).now
         },
         headers: @auth_header,
         as: :json

    assert_response :unauthorized
    assert_equal 'invalid_totp_challenge', response.parsed_body['code']
  end

  test 'rejects invalid signed challenge' do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    post '/api/browser/auth/unlock', headers: @auth_header, as: :json

    post '/api/browser/auth/unlock',
         params: {
           challengeId: response.parsed_body.fetch('challengeId'),
           unlockSignature: Base64.strict_encode64('invalid-signature')
         },
         headers: @auth_header,
         as: :json

    assert_response :unauthorized
    assert_equal 'invalid_unlock_proof', response.parsed_body['code']
  end

  test 'returns unauthorized when static api token is missing' do
    post '/api/browser/auth/unlock', as: :json

    assert_response :unauthorized
    assert_equal 'invalid_api_token', response.parsed_body['code']
  end

  test 'returns unauthorized when static api token is invalid' do
    post '/api/browser/auth/unlock',
         headers: { 'Authorization' => 'Bearer wrong-token' },
         as: :json

    assert_response :unauthorized
    assert_equal 'invalid_api_token', response.parsed_body['code']
  end

  private

  def post_signed_unlock(extra_params = {})
    post '/api/browser/auth/unlock', headers: @auth_header, as: :json
    challenge_id = response.parsed_body.fetch('challengeId')
    challenge = response.parsed_body.fetch('challenge')

    post '/api/browser/auth/unlock',
         params: {
           challengeId: challenge_id,
           unlockSignature: Base64.strict_encode64(
             VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.sign(OpenSSL::Digest.new('SHA256'), challenge)
           )
         }.merge(extra_params),
         headers: @auth_header,
         as: :json
  end

  def restore_env(key, value)
    value.nil? ? ENV.delete(key) : ENV[key] = value
  end
end
