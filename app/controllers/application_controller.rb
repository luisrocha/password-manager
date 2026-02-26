class ApplicationController < ActionController::Base
  MASTER_SESSION_TTL = 12.hours

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_master_password

  private

  def require_master_password
    return if unlocked_session?

    redirect_to unlock_path
  end

  def unlocked_session?
    timestamp = session[:master_unlocked_at]
    return false if timestamp.blank?

    unlocked_at = Time.zone.at(timestamp.to_i)
    return true if unlocked_at >= MASTER_SESSION_TTL.ago

    session.delete(:master_unlocked_at)
    false
  end
end
