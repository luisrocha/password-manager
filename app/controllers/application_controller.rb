class ApplicationController < ActionController::Base
  VAULT_SESSION_TTL = 12.hours

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_vault_unlock

  private

  def require_vault_unlock
    return if unlocked_session?

    redirect_to unlock_path
  end

  def unlocked_session?
    timestamp = session[:vault_unlocked_at]
    return false if timestamp.blank?

    unlocked_at = Time.zone.at(timestamp.to_i)
    return true if unlocked_at >= VAULT_SESSION_TTL.ago

    session.delete(:vault_unlocked_at)
    false
  end
end
