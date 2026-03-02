class Api::Browser::AuthController < ActionController::API
  before_action :authenticate_static_api_token!

  def unlock
    unless MasterPassword.valid?(unlock_params[:master_password] || unlock_params[:masterPassword])
      render json: { error: "Invalid master password", code: "invalid_master_password" }, status: :unauthorized
      return
    end

    issued_token = BrowserJwt.issue_encrypted_token
    render json: {
      token: issued_token[:token],
      expiresAt: issued_token[:expires_at].iso8601,
      tokenType: "Bearer"
    }
  end

  private

  def unlock_params
    params.permit(:master_password, :masterPassword)
  end

  def authenticate_static_api_token!
    expected_token = ENV["PASSWORD_MANAGER_API_TOKEN"].to_s
    provided_token = bearer_token

    unless expected_token.present? && valid_token?(provided_token, expected_token)
      render json: { error: "Unauthorized", code: "invalid_api_token" }, status: :unauthorized
    end
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
end
