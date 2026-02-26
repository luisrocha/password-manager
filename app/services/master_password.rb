require "openssl"

module MasterPassword
  module_function

  def configured_password
    ENV["MASTER_PASSWORD"].presence || Rails.application.credentials.dig(:master_password)
  end

  def configured?
    configured_password.present?
  end

  def valid?(candidate)
    return false if candidate.blank? || !configured?

    ActiveSupport::SecurityUtils.secure_compare(digest(candidate), digest(configured_password))
  end

  def digest(value)
    OpenSSL::Digest::SHA256.hexdigest(value.to_s)
  end
end
