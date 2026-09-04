require "test_helper"
require "open3"

class ProductionBootTest < ActiveSupport::TestCase
  ENCRYPTION_KEYS = %w[
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
  ]

  test "asset build boot does not require runtime environment variables" do
    _, error, status = production_boot("SECRET_KEY_BASE_DUMMY" => "1", "APP_HOST" => nil)

    assert_predicate status, :success?, error
  end

  test "runtime boot requires production encryption keys" do
    _, error, status = production_boot

    assert_not_predicate status, :success?
    assert_includes error, "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"
  end

  private

  def production_boot(environment = {})
    environment = {
      "RAILS_ENV" => "production",
      "APP_HOST" => "portfolio.invalid",
      "SECRET_KEY_BASE_DUMMY" => nil,
      **ENCRYPTION_KEYS.index_with(nil),
      **environment
    }

    Open3.capture3(environment, RbConfig.ruby, Rails.root.join("bin/rails").to_s, "runner", "true")
  end
end
