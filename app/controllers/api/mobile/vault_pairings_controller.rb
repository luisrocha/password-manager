class Api::Mobile::VaultPairingsController < ActionController::API
  include RateLimitResponse

  PAIRING_REDEEM_THROTTLE_LIMIT = ENV.fetch("PASSWORD_MANAGER_MOBILE_PAIRING_REDEEM_THROTTLE_LIMIT", 20).to_i

  rate_limit to: PAIRING_REDEEM_THROTTLE_LIMIT,
    within: 1.minute,
    only: :redeem,
    with: :render_rate_limit_response,
    name: "mobile_pairing_redeem"

  def redeem
    encrypted_vault_backup = MobileVaultPairing.redeem(params[:code])

    if encrypted_vault_backup.present?
      device, token = MobileDevice.issue!(name: params[:device_name].presence || params[:deviceName].presence || "Mobile app")
      render json: {
        encryptedVaultBackup: encrypted_vault_backup,
        device: {
          id: device.id.to_s,
          name: device.name
        },
        deviceToken: token
      }
    else
      render json: {
        error: "Pairing code expired or invalid.",
        code: "pairing_not_found"
      }, status: :not_found
    end
  end
end
