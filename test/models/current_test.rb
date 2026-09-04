require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "exposes admin_user only after second factor verification" do
    user = admin_users(:owner)
    pending = user.admin_sessions.create!(state: :pending_totp)
    verified = user.admin_sessions.create!(state: :verified)

    Current.admin_session = pending
    assert_nil Current.admin_user

    Current.admin_session = verified
    assert_equal user, Current.admin_user
  end
end
