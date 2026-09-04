require "test_helper"

class Admin::PasswordResetsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Rails.cache.clear
    clear_enqueued_jobs
    @user = admin_users(:owner)
  end

  teardown do
    Rails.cache.clear
    clear_enqueued_jobs
  end

  test "known and unknown emails receive the same generic response" do
    assert_enqueued_email_with AdminPasswordMailer, :reset, args: [@user] do
      post admin_password_reset_path, params: { password_reset: { email: @user.email } }
    end
    known = [response.status, response.location, flash[:notice]]

    clear_enqueued_jobs
    post admin_password_reset_path, params: { password_reset: { email: "missing@example.com" } }
    unknown = [response.status, response.location, flash[:notice]]

    assert_equal known, unknown
    assert_equal "If that email is the owner account, a reset link has been sent.", flash[:notice]
    assert_enqueued_emails 0
  end

  test "reset requests are limited to three per IP each hour" do
    3.times do
      post admin_password_reset_path, params: { password_reset: { email: @user.email } }
      assert_redirected_to new_admin_session_path
    end
    assert_enqueued_emails 3

    post admin_password_reset_path, params: { password_reset: { email: @user.email } }
    assert_redirected_to new_admin_session_path
    assert_equal "If that email is the owner account, a reset link has been sent.", flash[:notice]
    assert_enqueued_emails 3
  end

  test "valid reset changes password revokes sessions and invalidates token" do
    session_record = @user.admin_sessions.create!(state: :verified)
    token = @user.password_reset_token

    patch admin_password_reset_path, params: {
      token: token,
      admin_password_reset: {
        password: "new correct horse battery staple",
        password_confirmation: "new correct horse battery staple"
      }
    }

    assert_redirected_to new_admin_session_path
    assert @user.reload.authenticate("new correct horse battery staple")
    assert_not AdminSession.exists?(session_record.id)
    assert_nil AdminUser.find_by_password_reset_token(token)
  end

  test "reset form URL contains no bearer token" do
    get edit_admin_password_reset_path

    assert_response :success
    assert_select "input[name=token][autocomplete=off]"
    assert_not_includes request.fullpath, "token="
  end

  test "expired token fails with a safe redirect" do
    token = @user.password_reset_token
    travel 31.minutes
    patch admin_password_reset_path, params: {
      token: token,
      admin_password_reset: { password: "new correct horse battery staple", password_confirmation: "new correct horse battery staple" }
    }

    assert_redirected_to new_admin_password_reset_path
    assert_equal "This reset code is invalid or expired.", flash[:alert]
  end

  test "altered token fails with the same safe redirect" do
    patch admin_password_reset_path, params: {
      token: "#{@user.password_reset_token}altered",
      admin_password_reset: { password: "new correct horse battery staple", password_confirmation: "new correct horse battery staple" }
    }

    assert_redirected_to new_admin_password_reset_path
    assert_equal "This reset code is invalid or expired.", flash[:alert]
  end

  test "password validation preserves the token form without changing password" do
    token = @user.password_reset_token
    patch admin_password_reset_path, params: {
      token: token,
      admin_password_reset: { password: "short", password_confirmation: "different" }
    }

    assert_response :unprocessable_entity
    assert_select "input[name=token][value=?]", token
    assert @user.reload.authenticate(TEST_PASSWORD)
  end
end
