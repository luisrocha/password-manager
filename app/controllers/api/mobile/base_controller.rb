class Api::Mobile::BaseController < ActionController::API
  include RateLimitResponse

  MOBILE_SYNC_THROTTLE_LIMIT = ENV.fetch("PASSWORD_MANAGER_MOBILE_SYNC_THROTTLE_LIMIT", 60).to_i

  rate_limit to: MOBILE_SYNC_THROTTLE_LIMIT,
    within: 1.minute,
    with: :render_rate_limit_response,
    name: "mobile_sync"

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
