# frozen_string_literal: true

class VaultUnlockProof
  def self.valid?(challenge:, signature:, public_key_spki:)
    new(challenge:, signature:, public_key_spki:).valid?
  end

  def initialize(challenge:, signature:, public_key_spki:)
    @challenge = challenge.to_s
    @signature = signature.to_s
    @public_key_spki = public_key_spki.to_s
  end

  def valid?
    return false if challenge.blank? || signature.blank? || public_key_spki.blank?

    public_key.verify(
      OpenSSL::Digest.new('SHA256'),
      normalized_signature,
      challenge
    )
  rescue ArgumentError, OpenSSL::PKey::PKeyError, OpenSSL::ASN1::ASN1Error
    false
  end

  private

  attr_reader :challenge, :signature, :public_key_spki

  def public_key
    OpenSSL::PKey.read(Base64.strict_decode64(public_key_spki))
  end

  def normalized_signature
    decoded_signature = Base64.strict_decode64(signature)
    return decoded_signature unless decoded_signature.bytesize == 64

    OpenSSL::ASN1::Sequence([
                              OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(decoded_signature.byteslice(0, 32), 2)),
                              OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(decoded_signature.byteslice(32, 32), 2))
                            ]).to_der
  end
end
