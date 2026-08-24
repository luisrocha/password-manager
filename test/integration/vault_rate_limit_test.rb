# frozen_string_literal: true

require 'test_helper'

class VaultRateLimitTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test 'rate limits unlock posts with a generic response' do
    get unlock_url

    SessionsController::UNLOCK_THROTTLE_LIMIT.times { post unlock_url }
    post unlock_url

    assert_response :too_many_requests
    assert_equal 'too_many_requests', response.parsed_body['code']
    assert_equal '60', response.headers['Retry-After']
  end

  test 'rate limits setup token verification' do
    SessionsController::SETUP_TOKEN_THROTTLE_LIMIT.times do
      post '/unlock/verify_setup_token', params: { setup_token: 'wrong-token' }, as: :json
    end
    post '/unlock/verify_setup_token', params: { setup_token: 'wrong-token' }, as: :json

    assert_response :too_many_requests
    assert_equal 'too_many_requests', response.parsed_body['code']
  end

  test 'rate limits backup key verification' do
    SessionsController::BACKUP_VERIFY_THROTTLE_LIMIT.times do
      post '/unlock/verify_backup_key', params: { signing_public_key_spki: 'invalid' }, as: :json
    end
    post '/unlock/verify_backup_key', params: { signing_public_key_spki: 'invalid' }, as: :json

    assert_response :too_many_requests
    assert_equal 'too_many_requests', response.parsed_body['code']
  end

  test 'rate limits browser api unlock attempts' do
    Api::Browser::AuthController::API_UNLOCK_THROTTLE_LIMIT.times do
      post '/api/browser/auth/unlock', as: :json
    end
    post '/api/browser/auth/unlock', as: :json

    assert_response :too_many_requests
    assert_equal 'too_many_requests', response.parsed_body['code']
  end

  test 'rate limits mobile pairing redemption attempts' do
    Api::Mobile::VaultPairingsController::PAIRING_REDEEM_THROTTLE_LIMIT.times do
      post '/api/mobile/vault_pairings/redeem', params: { code: 'NOPE-0000' }, as: :json
    end
    post '/api/mobile/vault_pairings/redeem', params: { code: 'NOPE-0000' }, as: :json

    assert_response :too_many_requests
    assert_equal 'too_many_requests', response.parsed_body['code']
  end

  test 'rate limits mobile sync attempts' do
    _device, token = MobileDevice.issue!(name: 'Luis Pixel')

    Api::Mobile::BaseController::MOBILE_SYNC_THROTTLE_LIMIT.times do
      get '/api/mobile/credentials/sync', headers: { 'Authorization' => "Bearer #{token}" }, as: :json
    end
    get '/api/mobile/credentials/sync', headers: { 'Authorization' => "Bearer #{token}" }, as: :json

    assert_response :too_many_requests
    assert_equal 'too_many_requests', response.parsed_body['code']
  end
end
