ENV["RAILS_ENV"] ||= "test"
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

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |file| require file }

# ponytail: minitest 6 removed minitest/mock; a singleton-method stub with
# restore covers the few delivery-failure tests. Swap for a stub library if
# call assertions are ever needed.
module MethodStubbing
  def stub_method(owner, name, implementation)
    original = owner.method(name)
    owner.define_singleton_method(name, implementation)
    yield
  ensure
    owner.define_singleton_method(name, original)
  end
end

class ActiveSupport::TestCase
  include AdminAuthenticationTestHelper
  include MethodStubbing
end

class ActionDispatch::IntegrationTest
  include AdminAuthenticationTestHelper
end
