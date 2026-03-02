require "active_support/core_ext/integer/time"
require "base64"
require "json"
require "openssl"

module BrowserJwt
  module_function

  ISSUER = "password-manager".freeze
  AUDIENCE = "password-manager-extension".freeze
  ALGORITHM = "HS256".freeze
  ENCRYPTION_CIPHER = "aes-256-gcm".freeze
  TOKEN_PURPOSE = "browser-api-jwt".freeze
  DEFAULT_TTL_SECONDS = 15.minutes.to_i

  def issue_encrypted_token(expires_in: token_ttl_seconds, now: Time.current)
    issued_at = now.to_i
    expires_at = (now + expires_in).to_i

    payload = {
      "iss" => ISSUER,
      "aud" => AUDIENCE,
      "iat" => issued_at,
      "exp" => expires_at
    }

    jwt = encode_jwt(payload)
    encrypted_token = encryptor.encrypt_and_sign(jwt, purpose: TOKEN_PURPOSE)

    {
      token: encrypted_token,
      expires_at: Time.at(expires_at).utc
    }
  end

  def verify_encrypted_token(encrypted_token, now: Time.current)
    return { ok: false, code: :missing } if encrypted_token.blank?

    jwt = encryptor.decrypt_and_verify(encrypted_token, purpose: TOKEN_PURPOSE)
    payload = decode_jwt(jwt)

    return { ok: false, code: :invalid } unless payload["iss"] == ISSUER && payload["aud"] == AUDIENCE
    return { ok: false, code: :expired } if payload["exp"].to_i <= now.to_i

    { ok: true, payload: payload }
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    { ok: false, code: :invalid }
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    { ok: false, code: :invalid }
  rescue JWTError
    { ok: false, code: :invalid }
  end

  def token_ttl_seconds
    raw_value = ENV.fetch("PASSWORD_MANAGER_BROWSER_JWT_TTL_SECONDS", DEFAULT_TTL_SECONDS).to_i
    raw_value.positive? ? raw_value : DEFAULT_TTL_SECONDS
  end

  def encode_jwt(payload)
    header = { "alg" => ALGORITHM, "typ" => "JWT" }
    encoded_header = urlsafe_encode(header.to_json)
    encoded_payload = urlsafe_encode(payload.to_json)
    signing_input = [encoded_header, encoded_payload].join(".")
    signature = OpenSSL::HMAC.digest("SHA256", signing_secret, signing_input)

    [encoded_header, encoded_payload, urlsafe_encode(signature)].join(".")
  end

  def decode_jwt(jwt)
    segments = jwt.to_s.split(".")
    raise JWTError, "Malformed JWT" unless segments.size == 3

    encoded_header, encoded_payload, encoded_signature = segments
    signing_input = [encoded_header, encoded_payload].join(".")
    expected_signature = OpenSSL::HMAC.digest("SHA256", signing_secret, signing_input)
    provided_signature = urlsafe_decode(encoded_signature)

    unless secure_compare(provided_signature, expected_signature)
      raise JWTError, "Invalid signature"
    end

    header = JSON.parse(urlsafe_decode(encoded_header))
    raise JWTError, "Unexpected algorithm" unless header["alg"] == ALGORITHM

    payload = JSON.parse(urlsafe_decode(encoded_payload))
    raise JWTError, "Invalid exp" unless payload["exp"].to_i.positive?

    payload
  rescue JSON::ParserError, ArgumentError
    raise JWTError, "Malformed JWT"
  end

  def encryptor
    @encryptor ||= ActiveSupport::MessageEncryptor.new(encryption_key, cipher: ENCRYPTION_CIPHER)
  end

  def encryption_key
    key_generator.generate_key("browser-jwt-encryption", ActiveSupport::MessageEncryptor.key_len(ENCRYPTION_CIPHER))
  end

  def signing_secret
    key_generator.generate_key("browser-jwt-signing", 64)
  end

  def key_generator
    @key_generator ||= ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base)
  end

  def urlsafe_encode(value)
    Base64.urlsafe_encode64(value, padding: false)
  end

  def urlsafe_decode(value)
    Base64.urlsafe_decode64(value)
  end

  def secure_compare(a, b)
    return false if a.blank? || b.blank?
    return false unless a.bytesize == b.bytesize

    ActiveSupport::SecurityUtils.secure_compare(a, b)
  end

  class JWTError < StandardError; end
end
