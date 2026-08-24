# frozen_string_literal: true

class Api::Mobile::CredentialsController < Api::Mobile::BaseController
  MOBILE_SYNC_SIGNATURE_PREFIX = 'mobile-sync:v1:'

  before_action :verify_mobile_sync_signature!, only: :sync

  def sync
    render json: MobileCredentialSync.call(operations: sync_operations)
  end

  private

  def verify_mobile_sync_signature!
    signing_key = VaultSigningKey.current
    return render_invalid_mobile_sync_signature if signing_key.blank?
    return render_invalid_mobile_sync_signature unless mobile_sync_signing_key == signing_key.public_key_spki

    valid_signature = VaultUnlockProof.valid?(
      challenge: mobile_sync_signature_challenge,
      signature: mobile_sync_signature,
      public_key_spki: signing_key.public_key_spki
    )
    return if valid_signature

    render_invalid_mobile_sync_signature
  end

  def render_invalid_mobile_sync_signature
    render json: {
      error: 'Invalid mobile sync signature',
      code: 'invalid_mobile_sync_signature'
    }, status: :unauthorized
  end

  def mobile_sync_signature
    request.headers['X-Mobile-Sync-Signature'].to_s
  end

  def mobile_sync_signing_key
    request.headers['X-Mobile-Sync-Signing-Key'].to_s
  end

  def mobile_sync_signature_challenge
    "#{MOBILE_SYNC_SIGNATURE_PREFIX}#{request.request_method}:#{request.path}:#{request.raw_post}"
  end

  def sync_operations
    return [] unless request.post?

    params.fetch(:operations, []).map(&:to_unsafe_h)
  end
end
