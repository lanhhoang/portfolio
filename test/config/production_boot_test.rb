require "test_helper"
require "open3"

class ProductionBootTest < ActiveSupport::TestCase
  ENCRYPTION_KEYS = %w[
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
  ]
  SMTP_SETTINGS = %w[
    SMTP_ADDRESS
    SMTP_PORT
    SMTP_DOMAIN
    SMTP_USERNAME
    SMTP_PASSWORD
  ]

  test "asset build boot does not require runtime environment variables" do
    environment = {
      "SECRET_KEY_BASE_DUMMY" => "1",
      "APP_HOST" => nil,
      **SMTP_SETTINGS.index_with(nil)
    }
    _, error, status = production_boot(environment)

    assert_predicate status, :success?, error
  end

  test "runtime boot requires production encryption keys" do
    _, error, status = production_boot

    assert_not_predicate status, :success?
    assert_includes error, "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"
  end

  test "runtime boot requires SMTP settings" do
    environment = {
      **ENCRYPTION_KEYS.index_with { SecureRandom.base64(32) },
      "SMTP_ADDRESS" => nil
    }
    _, error, status = production_boot(environment)

    assert_not_predicate status, :success?
    assert_includes error, "SMTP_ADDRESS"
  end

  private

  def production_boot(environment = {})
    environment = {
      "RAILS_ENV" => "production",
      "APP_HOST" => "portfolio.invalid",
      "SECRET_KEY_BASE_DUMMY" => nil,
      "SMTP_ADDRESS" => "localhost",
      "SMTP_PORT" => "587",
      "SMTP_DOMAIN" => "portfolio.invalid",
      "SMTP_USERNAME" => "test",
      "SMTP_PASSWORD" => "test",
      **ENCRYPTION_KEYS.index_with(nil),
      **environment
    }

    Open3.capture3(environment, RbConfig.ruby, Rails.root.join("bin/rails").to_s, "runner", "true")
  end
end
