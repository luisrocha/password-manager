module RateLimitResponse
  extend ActiveSupport::Concern

  private

  def render_rate_limit_response
    response.set_header("Retry-After", "60")
    render json: { error: "Too many requests", code: "too_many_requests" }, status: :too_many_requests
  end
end
