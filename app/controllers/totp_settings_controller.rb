# frozen_string_literal: true

class TotpSettingsController < ApplicationController
  include RateLimitResponse

  CONFIRM_THROTTLE_LIMIT = ENV.fetch('PASSWORD_MANAGER_TOTP_CONFIRM_THROTTLE_LIMIT', 10).to_i

  rate_limit to: CONFIRM_THROTTLE_LIMIT,
             within: 1.minute,
             only: :confirm,
             with: :render_rate_limit_response,
             name: 'totp_confirm'

  def create
    session[:pending_totp_secret] = TotpSetting.generate_secret
    redirect_to security_path, notice: 'Scan the QR code to finish enabling two-factor authentication.',
                               status: :see_other
  end

  def confirm
    if session[:pending_totp_secret].blank?
      redirect_to security_path, alert: 'Start two-factor setup again.', status: :see_other
      return
    end

    setting = TotpSetting.new(secret: session[:pending_totp_secret])

    unless setting.verify(params[:code])
      redirect_to security_path, alert: 'Two-factor code is invalid.', status: :see_other
      return
    end

    recovery_codes = TotpSetting.generate_recovery_codes
    TotpSetting.current&.destroy!
    TotpSetting.create!(
      secret: setting.secret,
      enabled_at: Time.current,
      recovery_codes:
    )
    session.delete(:pending_totp_secret)
    session[:totp_recovery_codes] = recovery_codes
    TotpRememberedClient.revoke_all!
    cookies.delete(:totp_remembered_client)
    redirect_to security_path, notice: 'Two-factor authentication enabled.', status: :see_other
  end

  def destroy
    TotpSetting.current&.destroy!
    TotpRememberedClient.revoke_all!
    session.delete(:pending_totp_secret)
    cookies.delete(:totp_remembered_client)
    redirect_to security_path, notice: 'Two-factor authentication disabled.', status: :see_other
  end
end
