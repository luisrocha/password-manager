# frozen_string_literal: true

class ApplicationController < ActionController::Base
  DEFAULT_VAULT_SESSION_TTL_MINUTES = 30

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_vault_unlock
  after_action :prevent_authenticated_page_cache
  helper_method :extension_handoff_id, :vault_unlocked?

  def self.vault_session_ttl
    minutes = ENV.fetch('PASSWORD_MANAGER_VAULT_SESSION_TTL_MINUTES', DEFAULT_VAULT_SESSION_TTL_MINUTES).to_i
    minutes = DEFAULT_VAULT_SESSION_TTL_MINUTES if minutes <= 0

    minutes.minutes
  end

  private

  def require_vault_unlock
    return if unlocked_session?

    redirect_params = {}
    if params[:extension_id].present?
      session[:extension_id] = params[:extension_id]
      redirect_params[:extension_id] = params[:extension_id]
    end

    redirect_to unlock_path(redirect_params)
  end

  def extension_handoff_id
    params[:extension_id].presence || session[:extension_id].presence
  end

  def vault_unlocked?
    unlocked_session?
  end

  def unlocked_session?
    timestamp = session[:vault_unlocked_at]
    return false if timestamp.blank?

    unlocked_at = Time.zone.at(timestamp.to_i)
    return true if unlocked_at >= self.class.vault_session_ttl.ago

    session.delete(:vault_unlocked_at)
    false
  end

  def prevent_authenticated_page_cache
    return unless vault_unlocked?

    response.headers['Cache-Control'] = 'no-store'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'
  end
end
