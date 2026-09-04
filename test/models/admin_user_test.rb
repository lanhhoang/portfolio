require "test_helper"

class AdminUserTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "normalizes email and authenticates a fourteen character password" do
    user = admin_users(:owner)
    password = "12345678901234"
    user.update!(email: "  OWNER@Example.COM ", password: password, password_confirmation: password)

    assert_equal "owner@example.com", user.email
    assert_equal user, AdminUser.authenticate_by(email: "owner@example.com", password: password)
    assert_not_equal password, user.password_digest
  end

  test "rejects short passwords and a second owner" do
    short = AdminUser.new(email: "other@example.com", password: "1234567890123", totp_secret: TEST_TOTP_SECRET)

    assert_not short.valid?
    assert_includes short.errors[:password], "is too short (minimum is 14 characters)"
    assert_raises(ActiveRecord::RecordNotUnique) do
      AdminUser.create!(email: "other@example.com", password: TEST_PASSWORD, totp_secret: TEST_TOTP_SECRET)
    end
  end

  test "stores the TOTP secret as ciphertext" do
    user = admin_users(:owner)
    stored = AdminUser.connection.select_value(
      AdminUser.sanitize_sql_array([ "SELECT totp_secret FROM admin_users WHERE id = ?", user.id ])
    )

    assert_equal TEST_TOTP_SECRET, user.reload.totp_secret
    assert_not_equal TEST_TOTP_SECRET, stored
    assert_not_includes stored, TEST_TOTP_SECRET
  end

  test "accepts a current TOTP once and rejects replay" do
    travel_to Time.zone.parse("2026-09-02 12:00:00 UTC") do
      user = admin_users(:owner)
      code = ROTP::TOTP.new(TEST_TOTP_SECRET).at(Time.current)

      assert_equal true, user.verify_totp(code)
      assert_equal false, user.verify_totp(code)
    end
  end

  test "accepts one interval of TOTP clock drift and rejects malformed input" do
    travel_to Time.zone.parse("2026-09-02 12:00:00 UTC") do
      user = admin_users(:owner)
      totp = ROTP::TOTP.new(TEST_TOTP_SECRET)
      previous_code = totp.at(30.seconds.ago)
      too_old_code = totp.at(60.seconds.ago)

      assert_equal true, user.verify_totp(previous_code)
      assert_equal false, user.verify_totp(too_old_code)
      assert_equal false, user.verify_totp("12-abcd")
      assert_equal false, user.verify_totp(nil)
    end
  end

  test "recovery codes are high entropy digests and each code works once" do
    user = admin_users(:owner)
    codes = user.replace_recovery_codes
    stored = user.reload.recovery_code_digests.to_json

    assert_equal 10, codes.length
    assert_equal 10, codes.uniq.length
    assert codes.all? { |code| code.match?(/\A[0-9A-F]{4}(?:-[0-9A-F]{4}){4}\z/) }
    codes.each { |code| assert_not_includes stored, code.delete("-") }
    assert_equal true, user.consume_recovery_code(codes.first.downcase)
    assert_equal false, user.consume_recovery_code(codes.first)
    assert_equal 9, user.reload.recovery_code_digests.length
    assert_equal false, user.consume_recovery_code("#{codes.second}!not-valid")
  end

  test "password reset token expires and changing the password invalidates it" do
    user = admin_users(:owner)
    token = user.password_reset_token

    assert_equal user, AdminUser.find_by_password_reset_token(token)
    travel 31.minutes
    assert_nil AdminUser.find_by_password_reset_token(token)

    travel_back
    token = user.password_reset_token
    user.update!(password: "a different secure password", password_confirmation: "a different secure password")
    assert_nil AdminUser.find_by_password_reset_token(token)
  end
end
