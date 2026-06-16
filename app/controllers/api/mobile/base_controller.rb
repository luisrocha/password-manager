class Api::Mobile::BaseController < ActionController::API
  before_action :authenticate_mobile_device!

  private

  attr_reader :current_mobile_device

  def authenticate_mobile_device!
    @current_mobile_device = MobileDevice.authenticate(bearer_token)
    return if current_mobile_device.present?

    render json: { error: "Unauthorized", code: "invalid_mobile_device_token" }, status: :unauthorized
  end

  def bearer_token
    authorization = request.headers["Authorization"].to_s
    match = authorization.match(/\ABearer (?<token>.+)\z/)
    match && match[:token]
  end
end
