class SessionsController < ApplicationController
  skip_before_action :require_vault_unlock, only: %i[new create verify_backup_key verify_setup_token]

  def new
    session[:unlock_challenge] = SecureRandom.urlsafe_base64(32)
    @vault_registered = VaultSigningKey.exists?
    @setup_token_required = !@vault_registered && VaultSetupToken.required?
    @setup_token_configured = VaultSetupToken.token_configured?
  end

  def create
    unless valid_unlock_proof?
      redirect_to unlock_path, alert: "Vault unlock proof is invalid."
      return
    end

    session[:vault_unlocked_at] = Time.current.to_i
    session.delete(:unlock_challenge)
    redirect_to credentials_path, notice: "Vault unlocked.", status: :see_other
  end

  def verify_backup_key
    signing_key = VaultSigningKey.current
    if signing_key.blank?
      render json: { ok: true }
    elsif signing_key.public_key_spki == params[:signing_public_key_spki].to_s
      render json: { ok: true }
    else
      render json: { ok: false, code: "backup_key_mismatch" }, status: :unprocessable_entity
    end
  end

  def verify_setup_token
    if VaultSigningKey.exists?
      render json: { ok: false, code: "vault_already_registered" }, status: :unprocessable_entity
    elsif VaultSetupToken.valid?(params[:setup_token])
      render json: { ok: true }
    else
      render json: { ok: false, code: "invalid_setup_token" }, status: :unauthorized
    end
  end

  def destroy
    reset_session
    redirect_to unlock_path, notice: "Vault locked."
  end

  private

  def valid_unlock_proof?
    return false if session[:unlock_challenge].blank?

    signing_key = VaultSigningKey.current
    return false if signing_key.blank? && Credential.exists?
    registering_first_key = signing_key.blank?
    return false if registering_first_key && !VaultSetupToken.valid?(params[:setup_token])

    public_key_spki = signing_key&.public_key_spki || params[:signing_public_key_spki]
    return false unless VaultUnlockProof.valid?(
      challenge: session[:unlock_challenge],
      signature: params[:unlock_signature],
      public_key_spki:
    )

    VaultSigningKey.create!(public_key_spki:) if registering_first_key
    true
  end
end
