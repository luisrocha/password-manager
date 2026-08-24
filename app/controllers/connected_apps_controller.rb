# frozen_string_literal: true

class ConnectedAppsController < ApplicationController
  COMPACT_MOBILE_VAULT_SCHEMA = {
    'v' => 1,
    'd' => {
      'p' => String,
      'e' => String,
      's' => { 'p' => String, 'e' => String, 'i' => String },
      'k' => { 'v' => Numeric, 't' => Numeric, 'm' => Numeric, 'p' => Numeric, 'h' => Numeric, 's' => String },
      'c' => { 'i' => String }
    }
  }.freeze
  VAULT_BACKUP_SCHEMA = {
    'version' => 1,
    'publicKey' => String,
    'encryptedPrivateKey' => String,
    'signing' => { 'publicKeySpki' => String, 'encryptedPrivateKey' => String, 'iv' => String },
    'kdf' => { 'salt' => String },
    'encryption' => { 'iv' => String }
  }.freeze

  before_action :prevent_cached_access

  def index
    @mobile_devices = MobileDevice.sorted
  end

  def create_mobile_pairing
    encrypted_vault_backup = params.require(:encrypted_vault_backup).to_s
    validate_encrypted_vault_backup!(encrypted_vault_backup)

    render json: MobileVaultPairing.create!(encrypted_vault_backup)
  rescue ActionController::ParameterMissing, JSON::ParserError, InvalidMobileVaultPayloadError
    render json: { error: 'Invalid encrypted vault backup.' }, status: :unprocessable_entity
  end

  def revoke_mobile_device
    MobileDevice.find(params[:id]).revoke!

    redirect_to connected_apps_path, notice: 'Mobile app access revoked.', status: :see_other
  end

  def destroy_mobile_device
    device = MobileDevice.find(params[:id])

    if device.revoked_at.present?
      device.destroy!
      redirect_to connected_apps_path, notice: 'Revoked mobile app entry deleted.', status: :see_other
    else
      redirect_to connected_apps_path, alert: 'Revoke mobile app access before deleting it.', status: :see_other
    end
  end

  private

  def prevent_cached_access
    response.headers['Cache-Control'] = 'no-store'
    response.headers['Pragma'] = 'no-cache'
  end

  class InvalidMobileVaultPayloadError < StandardError; end

  def validate_encrypted_vault_backup!(serialized_backup)
    payload = JSON.parse(serialized_backup)

    if payload.is_a?(Hash) && payload['t'] == 'pmv'
      validate_compact_mobile_vault_payload!(payload)
    else
      validate_vault_backup_payload!(payload)
    end
  end

  def validate_compact_mobile_vault_payload!(payload)
    raise InvalidMobileVaultPayloadError unless payload_matches_schema?(payload, COMPACT_MOBILE_VAULT_SCHEMA)
  end

  def validate_vault_backup_payload!(payload)
    raise InvalidMobileVaultPayloadError unless payload_matches_schema?(payload, VAULT_BACKUP_SCHEMA)
  end

  def payload_matches_schema?(payload, schema)
    return false unless payload.is_a?(Hash)

    schema.all? do |key, expected|
      value = payload[key]
      case expected
      when Hash
        payload_matches_schema?(value, expected)
      when Module
        value.is_a?(expected)
      else
        value == expected
      end
    end
  end
end
