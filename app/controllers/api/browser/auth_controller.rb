class Api::Browser::AuthController < ActionController::API
  include RateLimitResponse

  API_UNLOCK_THROTTLE_LIMIT = ENV.fetch("PASSWORD_MANAGER_API_UNLOCK_THROTTLE_LIMIT", 30).to_i

  rate_limit to: API_UNLOCK_THROTTLE_LIMIT,
    within: 1.minute,
    only: :unlock,
    with: :render_rate_limit_response,
    name: "browser_api_unlock"
  before_action :authenticate_static_api_token!

  def unlock
    if unlock_params[:challenge_id].blank? && unlock_params[:challengeId].blank?
      issue_challenge
      return
    end

    unless valid_unlock_proof?
      render json: { error: "Invalid unlock proof", code: "invalid_unlock_proof" }, status: :unauthorized
      return
    end

    issued_token = BrowserJwt.issue_encrypted_token
    render json: {
      token: issued_token[:token],
      expiresAt: issued_token[:expires_at].iso8601,
      tokenType: "Bearer"
    }
  end

  private

  def unlock_params
    params.permit(:challenge_id, :challengeId, :unlock_signature, :unlockSignature, :signing_public_key_spki, :signingPublicKeySpki)
  end

  def issue_challenge
    challenge = SecureRandom.urlsafe_base64(48)

    render json: {
      challengeId: challenge_verifier.generate(challenge, expires_in: 5.minutes, purpose: :browser_api_unlock),
      challenge: challenge
    }
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

  def challenge_verifier
    Rails.application.message_verifier(:browser_api_unlock_challenge)
  end

  def authenticate_static_api_token!
    expected_token = ENV["PASSWORD_MANAGER_API_TOKEN"].to_s
    provided_token = bearer_token

    unless expected_token.present? && valid_token?(provided_token, expected_token)
      render json: { error: "Unauthorized", code: "invalid_api_token" }, status: :unauthorized
    end
  end

  def bearer_token
    authorization = request.headers["Authorization"].to_s
    match = authorization.match(/\ABearer (?<token>.+)\z/)
    match && match[:token]
  end

  def valid_token?(provided_token, expected_token)
    return false if provided_token.blank?
    return false unless provided_token.bytesize == expected_token.bytesize

    ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
  end
end
