# frozen_string_literal: true

class SecurityController < ApplicationController
  def index
    @totp_setting = TotpSetting.current
    @pending_totp_secret = session[:pending_totp_secret]
    @pending_totp_setting = build_pending_totp_setting
    @recovery_codes = session.delete(:totp_recovery_codes)
  end

  private

  def build_pending_totp_setting
    return if @pending_totp_secret.blank?

    TotpSetting.new(secret: @pending_totp_secret)
  end
end
