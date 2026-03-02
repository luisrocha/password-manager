class Api::BaseController < ActionController::API
  before_action :authenticate_api_token!

  private

  def authenticate_api_token!
    expected_token = ENV["PASSWORD_MANAGER_API_TOKEN"].to_s
    provided_token = bearer_token

    if expected_token.present? && valid_token?(provided_token, expected_token)
      return
    end

    jwt_auth_result = BrowserJwt.verify_encrypted_token(provided_token)
    return if jwt_auth_result[:ok]

    if jwt_auth_result[:code] == :expired
      render_unauthorized(code: "token_expired", message: "Token expired")
      return
    end

    render_unauthorized(code: "invalid_token", message: "Unauthorized")
  end

  def bearer_token
    authorization = request.headers["Authorization"].to_s
    match = authorization.match(/\ABearer (?<token>.+)\z/)
    match && match[:token]
  end

  def valid_token?(provided_token, expected_token)
    return false if provided_token.blank?
    return false unless provided_token.bytesize == expected_token.bytesize

    ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
  end

  def render_unauthorized(code:, message:)
    render json: { error: message, code: code }, status: :unauthorized
  end
end
