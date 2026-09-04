require "test_helper"
require "rake"

class AdminCreateTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("admin:create")
    @task = Rake::Task["admin:create"]
    @original_email = ENV["ADMIN_EMAIL"]
    @original_password = ENV["ADMIN_PASSWORD"]
    AdminSession.delete_all
    AdminUser.delete_all
  end

  teardown do
    ENV["ADMIN_EMAIL"] = @original_email
    ENV["ADMIN_PASSWORD"] = @original_password
    @task.reenable
  end

  test "requires both environment variables" do
    ENV.delete("ADMIN_EMAIL")
    ENV.delete("ADMIN_PASSWORD")

    error = assert_raises(KeyError) { @task.invoke }
    assert_match "ADMIN_EMAIL", error.message
  end

  test "rejects invalid email and short password without creating an owner" do
    ENV["ADMIN_EMAIL"] = "not-an-email"
    ENV["ADMIN_PASSWORD"] = "deployment correct horse battery"
    error = assert_raises(ArgumentError) { @task.invoke }
    assert_equal "ADMIN_EMAIL must be a valid email address", error.message
    assert_equal 0, AdminUser.count

    @task.reenable
    ENV["ADMIN_EMAIL"] = "owner@example.com"
    ENV["ADMIN_PASSWORD"] = "short"
    error = assert_raises(ArgumentError) { @task.invoke }
    assert_equal "ADMIN_PASSWORD must be at least 14 characters", error.message
    assert_equal 0, AdminUser.count
  end

  test "creates one owner and prints usable enrollment material once" do
    ENV["ADMIN_EMAIL"] = "OWNER@example.com"
    ENV["ADMIN_PASSWORD"] = "deployment correct horse battery"

    output, = capture_io { @task.invoke }
    user = AdminUser.sole
    codes = output.lines.grep(/\A[0-9A-F]{4}(?:-[0-9A-F]{4}){4}\n\z/).map(&:strip)

    assert_equal "owner@example.com", user.email
    assert user.authenticate("deployment correct horse battery")
    assert_match %r{otpauth://totp/}, output
    assert_equal 10, codes.length
    assert user.consume_recovery_code(codes.first)
    assert_not_includes output, ENV.fetch("ADMIN_PASSWORD")
  end

  test "rerun resets credentials without adding an owner and revokes sessions" do
    existing = AdminUser.create!(
      email: "owner@example.com",
      password: TEST_PASSWORD,
      password_confirmation: TEST_PASSWORD,
      totp_secret: TEST_TOTP_SECRET
    )
    session_record = existing.admin_sessions.create!(state: :verified)
    old_secret = existing.totp_secret
    ENV["ADMIN_EMAIL"] = "new-owner@example.com"
    ENV["ADMIN_PASSWORD"] = "replacement correct horse battery"

    capture_io { @task.invoke }
    existing.reload

    assert_equal 1, AdminUser.count
    assert_equal "new-owner@example.com", existing.email
    assert_not_equal old_secret, existing.totp_secret
    assert existing.authenticate("replacement correct horse battery")
    assert_not AdminSession.exists?(session_record.id)
  end
end
