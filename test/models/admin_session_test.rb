require "test_helper"

class AdminSessionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup { @user = admin_users(:owner) }

  test "pending sessions expire after ten minutes" do
    record = @user.admin_sessions.create!(state: :pending_totp)

    assert_equal 10.minutes.from_now.to_i, record.expires_at.to_i
    assert_includes AdminSession.active, record
  end

  test "verified sessions expire after twelve hours" do
    record = @user.admin_sessions.create!(state: :verified)

    assert_predicate record, :verified?
    assert_equal 12.hours.from_now.to_i, record.expires_at.to_i
  end

  test "active excludes expired sessions" do
    record = @user.admin_sessions.create!(state: :pending_totp)

    travel 11.minutes
    assert_not_includes AdminSession.active, record
  end
end
