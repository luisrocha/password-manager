# frozen_string_literal: true

class Api::Browser::AuthController < ActionController::API
  include RateLimitResponse

  API_UNLOCK_THROTTLE_LIMIT = ENV.fetch('PASSWORD_MANAGER_API_UNLOCK_THROTTLE_LIMIT', 30).to_i
  TOTP_CHALLENGE_TTL = 5.minutes

  rate_limit to: API_UNLOCK_THROTTLE_LIMIT,
             within: 1.minute,
             only: :unlock,
             with: :render_rate_limit_response,
             name: 'browser_api_unlock'
  before_action :authenticate_static_api_token!

  def unlock
    if totp_challenge_id.present?
      verify_totp_challenge
      return
    end

    if unlock_params[:challenge_id].blank? && unlock_params[:challengeId].blank?
      issue_challenge
      return
    end

    unless valid_unlock_proof?
      render json: { error: 'Invalid unlock proof', code: 'invalid_unlock_proof' }, status: :unauthorized
      return
    end

    if TotpSetting.enabled? && !TotpRememberedClient.valid_token?(totp_remembered_client_token)
      issue_totp_challenge
      return
    end

    render_token_response
  end

  private

  def verify_totp_challenge
    unless verified_totp_challenge.present?
      render json: { error: 'Invalid two-factor challenge', code: 'invalid_totp_challenge' }, status: :unauthorized
      return
    end

    unless valid_second_factor_code?
      render json: { error: 'Invalid two-factor code', code: 'invalid_totp_code' }, status: :unauthorized
      return
    end

    remembered_client_token = TotpRememberedClient.issue! if remember_client?
    render_token_response(remembered_client_token:)
  end

  def render_token_response(remembered_client_token: nil)
    issued_token = BrowserJwt.issue_encrypted_token
    response_body = {
      token: issued_token[:token],
      expiresAt: issued_token[:expires_at].iso8601,
      tokenType: 'Bearer'
    }
    response_body[:totpRememberedClientToken] = remembered_client_token if remembered_client_token.present?

    render json: response_body
  end

  def unlock_params
    params.permit(
      :challenge_id,
      :challengeId,
      :unlock_signature,
      :unlockSignature,
      :totp_challenge_id,
      :totpChallengeId,
      :totp_code,
      :totpCode,
      :code,
      :remember_client,
      :rememberClient,
      :totp_remembered_client_token,
      :totpRememberedClientToken
    )
  end

  def issue_challenge
    challenge = SecureRandom.urlsafe_base64(48)

    render json: {
      challengeId: challenge_verifier.generate(challenge, expires_in: 5.minutes, purpose: :browser_api_unlock),
      challenge: challenge
    }
  end

  def issue_totp_challenge
    challenge = SecureRandom.urlsafe_base64(48)

    render json: {
      requiresTotp: true,
      totpChallengeId: totp_challenge_verifier.generate(challenge, expires_in: TOTP_CHALLENGE_TTL,
                                                                   purpose: :browser_api_totp),
      expiresAt: TOTP_CHALLENGE_TTL.from_now.iso8601
    }, status: :accepted
  end

  def valid_unlock_proof?
    registered_key = VaultSigningKey.first
    challenge = verified_challenge

    return false if registered_key.blank? || challenge.blank?

    VaultUnlockProof.valid?(
      challenge: challenge,
      signature: unlock_signature,
      public_key_spki: registered_key.public_key_spki
    )
  end

  def challenge_id
    unlock_params[:challenge_id].presence || unlock_params[:challengeId].presence
  end

  def unlock_signature
    unlock_params[:unlock_signature].presence || unlock_params[:unlockSignature].presence
  end

  def verified_challenge
    challenge_verifier.verified(challenge_id, purpose: :browser_api_unlock)
  end

  def totp_challenge_id
    unlock_params[:totp_challenge_id].presence || unlock_params[:totpChallengeId].presence
  end

  def verified_totp_challenge
    totp_challenge_verifier.verified(totp_challenge_id, purpose: :browser_api_totp)
  end

  def totp_code
    unlock_params[:totp_code].presence || unlock_params[:totpCode].presence || unlock_params[:code].presence
  end

  def valid_second_factor_code?
    setting = TotpSetting.current
    return false if setting.blank?

    setting.verify(totp_code) || setting.consume_recovery_code(totp_code)
  end

  def remember_client?
    remember_client = unlock_params[:remember_client].presence || unlock_params[:rememberClient].presence
    ActiveModel::Type::Boolean.new.cast(remember_client)
  end

  def totp_remembered_client_token
    unlock_params[:totp_remembered_client_token].presence || unlock_params[:totpRememberedClientToken].presence
  end

  def challenge_verifier
    Rails.application.message_verifier(:browser_api_unlock_challenge)
  end

  def totp_challenge_verifier
    Rails.application.message_verifier(:browser_api_totp_challenge)
  end

  def authenticate_static_api_token!
    return if BrowserApiToken.valid?(bearer_token)

    render json: { error: 'Unauthorized', code: 'invalid_api_token' }, status: :unauthorized
  end

  def bearer_token
    authorization = request.headers['Authorization'].to_s
    match = authorization.match(/\ABearer (?<token>.+)\z/)
    match && match[:token]
  end
end
