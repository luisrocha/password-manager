class ConnectedAppsController < ApplicationController
  before_action :prevent_cached_access

  def index; end

  def create_mobile_pairing
    encrypted_vault_backup = params.require(:encrypted_vault_backup).to_s
    validate_encrypted_vault_backup!(encrypted_vault_backup)

    render json: MobileVaultPairing.create!(encrypted_vault_backup)
  rescue ActionController::ParameterMissing, JSON::ParserError, InvalidMobileVaultPayloadError
    render json: { error: "Invalid encrypted vault backup." }, status: :unprocessable_entity
  end

  private

  def prevent_cached_access
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
  end

  class InvalidMobileVaultPayloadError < StandardError; end

  def validate_encrypted_vault_backup!(serialized_backup)
    payload = JSON.parse(serialized_backup)

    if payload.is_a?(Hash) && payload["t"] == "pmv"
      validate_compact_mobile_vault_payload!(payload)
    else
      validate_vault_backup_payload!(payload)
    end
  end

  def validate_compact_mobile_vault_payload!(payload)
    data = payload["d"]
    signing = data.is_a?(Hash) ? data["s"] : nil
    kdf = data.is_a?(Hash) ? data["k"] : nil
    encryption = data.is_a?(Hash) ? data["c"] : nil

    return if payload["v"] == 1 &&
      data.is_a?(Hash) &&
      data["p"].is_a?(String) &&
      data["e"].is_a?(String) &&
      signing.is_a?(Hash) &&
      signing["p"].is_a?(String) &&
      signing["e"].is_a?(String) &&
      signing["i"].is_a?(String) &&
      kdf.is_a?(Hash) &&
      kdf["v"].is_a?(Numeric) &&
      kdf["t"].is_a?(Numeric) &&
      kdf["m"].is_a?(Numeric) &&
      kdf["p"].is_a?(Numeric) &&
      kdf["h"].is_a?(Numeric) &&
      kdf["s"].is_a?(String) &&
      encryption.is_a?(Hash) &&
      encryption["i"].is_a?(String)

    raise InvalidMobileVaultPayloadError
  end

  def validate_vault_backup_payload!(payload)
    signing = payload.is_a?(Hash) ? payload["signing"] : nil
    kdf = payload.is_a?(Hash) ? payload["kdf"] : nil
    encryption = payload.is_a?(Hash) ? payload["encryption"] : nil

    return if payload.is_a?(Hash) &&
      payload["version"] == 1 &&
      payload["publicKey"].is_a?(String) &&
      payload["encryptedPrivateKey"].is_a?(String) &&
      signing.is_a?(Hash) &&
      signing["publicKeySpki"].is_a?(String) &&
      signing["encryptedPrivateKey"].is_a?(String) &&
      signing["iv"].is_a?(String) &&
      kdf.is_a?(Hash) &&
      kdf["salt"].is_a?(String) &&
      encryption.is_a?(Hash) &&
      encryption["iv"].is_a?(String)

    raise InvalidMobileVaultPayloadError
  end
end
