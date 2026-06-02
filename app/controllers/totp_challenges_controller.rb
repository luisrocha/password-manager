class TotpChallengesController < ApplicationController
  include RateLimitResponse

  CHALLENGE_THROTTLE_LIMIT = ENV.fetch("PASSWORD_MANAGER_TOTP_CHALLENGE_THROTTLE_LIMIT", 10).to_i
  PENDING_TOTP_TTL = 5.minutes

  skip_before_action :require_vault_unlock, only: %i[new create]
  before_action :require_pending_totp_unlock

  rate_limit to: CHALLENGE_THROTTLE_LIMIT,
    within: 1.minute,
    only: :create,
    with: :render_rate_limit_response,
    name: "totp_challenge"

  def new
  end

  def create
    unless TotpSetting.current&.verify(params[:code])
      redirect_to totp_challenge_path, alert: "Two-factor code is invalid.", status: :see_other
      return
    end

    session[:vault_unlocked_at] = Time.current.to_i
    session.delete(:pending_totp_unlocked_at)
    redirect_to credentials_path, notice: "Vault unlocked.", status: :see_other
  end

  private

  def require_pending_totp_unlock
    timestamp = session[:pending_totp_unlocked_at]
    return if timestamp.present? && Time.zone.at(timestamp.to_i) >= PENDING_TOTP_TTL.ago

    session.delete(:pending_totp_unlocked_at)
    redirect_to unlock_path, alert: "Unlock again to continue."
  end
end
