ENV["RAILS_ENV"] ||= "test"
ENV["MASTER_PASSWORD"] ||= "test-master-password"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module MasterPasswordIntegrationHelper
  def unlock!
    post unlock_url, params: { master_password: ENV.fetch("MASTER_PASSWORD") }
    follow_redirect! if response.redirect?
  end
end

class ActionDispatch::IntegrationTest
  include MasterPasswordIntegrationHelper
end
