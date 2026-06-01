class ApplicationController < ActionController::Base
  DEFAULT_VAULT_SESSION_TTL_MINUTES = 30

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_vault_unlock

  def self.vault_session_ttl
    minutes = ENV.fetch("PASSWORD_MANAGER_VAULT_SESSION_TTL_MINUTES", DEFAULT_VAULT_SESSION_TTL_MINUTES).to_i
    minutes = DEFAULT_VAULT_SESSION_TTL_MINUTES if minutes <= 0

    minutes.minutes
  end

  private

  def require_vault_unlock
    return if unlocked_session?

    redirect_to unlock_path
  end

  def unlocked_session?
    timestamp = session[:vault_unlocked_at]
    return false if timestamp.blank?

    unlocked_at = Time.zone.at(timestamp.to_i)
    return true if unlocked_at >= self.class.vault_session_ttl.ago

    session.delete(:vault_unlocked_at)
    false
  end
end
