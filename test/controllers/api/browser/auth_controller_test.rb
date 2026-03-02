require "test_helper"

class Api::Browser::AuthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_api_token = ENV["PASSWORD_MANAGER_API_TOKEN"]
    ENV["PASSWORD_MANAGER_API_TOKEN"] = "browser-static-token"
    @auth_header = { "Authorization" => "Bearer browser-static-token" }
  end

  teardown do
    ENV["PASSWORD_MANAGER_API_TOKEN"] = @previous_api_token
  end

  test "returns encrypted jwt token for valid master password" do
    post "/api/browser/auth/unlock",
      params: { masterPassword: ENV.fetch("MASTER_PASSWORD") },
      headers: @auth_header,
      as: :json

    assert_response :success
    assert response.parsed_body["token"].present?
    assert response.parsed_body["expiresAt"].present?
    assert_equal "Bearer", response.parsed_body["tokenType"]
  end

  test "returns unauthorized for invalid master password" do
    post "/api/browser/auth/unlock",
      params: { masterPassword: "wrong-password" },
      headers: @auth_header,
      as: :json

    assert_response :unauthorized
    assert_equal "invalid_master_password", response.parsed_body["code"]
  end

  test "returns unauthorized when static api token is missing" do
    post "/api/browser/auth/unlock",
      params: { masterPassword: ENV.fetch("MASTER_PASSWORD") },
      as: :json

    assert_response :unauthorized
    assert_equal "invalid_api_token", response.parsed_body["code"]
  end

  test "returns unauthorized when static api token is invalid" do
    post "/api/browser/auth/unlock",
      params: { masterPassword: ENV.fetch("MASTER_PASSWORD") },
      headers: { "Authorization" => "Bearer wrong-token" },
      as: :json

    assert_response :unauthorized
    assert_equal "invalid_api_token", response.parsed_body["code"]
  end
end
