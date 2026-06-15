class Api::Mobile::VaultPairingsController < ActionController::API
  def redeem
    encrypted_vault_backup = MobileVaultPairing.redeem(params[:code])

    if encrypted_vault_backup.present?
      render json: { encryptedVaultBackup: encrypted_vault_backup }
    else
      render json: {
        error: "Pairing code expired or invalid.",
        code: "pairing_not_found"
      }, status: :not_found
    end
  end
end
