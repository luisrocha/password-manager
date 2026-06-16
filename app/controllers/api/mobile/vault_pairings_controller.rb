class Api::Mobile::VaultPairingsController < ActionController::API
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
