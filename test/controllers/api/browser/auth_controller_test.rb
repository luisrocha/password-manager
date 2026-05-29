require "test_helper"

class Api::Browser::AuthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_api_token = ENV["PASSWORD_MANAGER_API_TOKEN"]
    ENV["PASSWORD_MANAGER_API_TOKEN"] = "browser-static-token"
    @auth_header = { "Authorization" => "Bearer browser-static-token" }
    Rails.cache.clear
  end

  teardown do
    ENV["PASSWORD_MANAGER_API_TOKEN"] = @previous_api_token
    Rails.cache.clear
  end

  test "issues an api unlock challenge" do
    post "/api/browser/auth/unlock", headers: @auth_header, as: :json

    assert_response :success
    assert response.parsed_body["challengeId"].present?
    assert response.parsed_body["challenge"].present?
    assert_nil response.parsed_body["token"]
  end

  test "returns encrypted jwt token for valid signed challenge" do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    post "/api/browser/auth/unlock", headers: @auth_header, as: :json
    challenge_id = response.parsed_body.fetch("challengeId")
    challenge = response.parsed_body.fetch("challenge")

    post "/api/browser/auth/unlock",
      params: {
        challengeId: challenge_id,
        unlockSignature: Base64.strict_encode64(
          VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.sign(OpenSSL::Digest::SHA256.new, challenge)
        )
      },
      headers: @auth_header,
      as: :json

    assert_response :success
    assert response.parsed_body["token"].present?
    assert response.parsed_body["expiresAt"].present?
    assert_equal "Bearer", response.parsed_body["tokenType"]
  end

  test "rejects invalid signed challenge" do
    VaultSigningKey.create!(
      public_key_spki: Base64.strict_encode64(VaultUnlockIntegrationHelper::TEST_UNLOCK_KEY.public_to_der)
    )
    post "/api/browser/auth/unlock", headers: @auth_header, as: :json

    post "/api/browser/auth/unlock",
      params: {
        challengeId: response.parsed_body.fetch("challengeId"),
        unlockSignature: Base64.strict_encode64("invalid-signature")
      },
      headers: @auth_header,
      as: :json

    assert_response :unauthorized
    assert_equal "invalid_unlock_proof", response.parsed_body["code"]
  end

  test "returns unauthorized when static api token is missing" do
    post "/api/browser/auth/unlock", as: :json

    assert_response :unauthorized
    assert_equal "invalid_api_token", response.parsed_body["code"]
  end

  test "returns unauthorized when static api token is invalid" do
    post "/api/browser/auth/unlock",
      headers: { "Authorization" => "Bearer wrong-token" },
      as: :json

    assert_response :unauthorized
    assert_equal "invalid_api_token", response.parsed_body["code"]
  end
end
