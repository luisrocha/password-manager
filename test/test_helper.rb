# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'factory_bot_rails'

ENV[VaultSetupToken::ENV_KEY] = 'test-setup-token' unless VaultSetupToken.token_configured?

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    include FactoryBot::Syntax::Methods
  end
end

module VaultUnlockIntegrationHelper
  TEST_UNLOCK_KEY = OpenSSL::PKey::EC.generate('prime256v1')

  def unlock!
    get unlock_url, headers: unlock_request_headers
    post unlock_url, params: unlock_proof_params, headers: unlock_request_headers
    follow_redirect! if response.redirect?
  end

  def unlock_proof_params
    challenge = response.body.match(/data-challenge="([^"]+)"/)[1]

    params = {
      unlock_signature: Base64.strict_encode64(TEST_UNLOCK_KEY.sign(OpenSSL::Digest.new('SHA256'), challenge)),
      signing_public_key_spki: Base64.strict_encode64(TEST_UNLOCK_KEY.public_to_der)
    }
    params[:setup_token] = ENV.fetch('PASSWORD_MANAGER_SETUP_TOKEN', nil) if VaultSetupToken.token_configured?

    params
  end

  def unlock_request_headers
    @unlock_request_headers ||= {
      'REMOTE_ADDR' => "192.0.2.#{SecureRandom.random_number(254) + 1}"
    }
  end
end

class ActionDispatch::IntegrationTest
  include VaultUnlockIntegrationHelper
end
