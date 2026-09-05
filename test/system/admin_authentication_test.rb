require "application_system_test_case"

class AdminAuthenticationTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @user = admin_users(:owner)
    @recovery_codes = @user.replace_recovery_codes
  end

  test "owner signs in with password and TOTP then signs out" do
    visit admin_root_path
    assert_current_path new_admin_session_path

    sign_in_owner

    assert_current_path admin_root_path
    assert_text "Dashboard"
    click_button "Sign out"

    assert_current_path new_admin_session_path
    visit admin_root_path
    assert_current_path new_admin_session_path
  end

  test "owner uses a recovery code only once" do
    sign_in_password_stage
    click_link "Use a recovery code"
    fill_in "Recovery code", with: @recovery_codes.first
    click_button "Use recovery code"
    assert_current_path admin_root_path

    click_button "Sign out"
    sign_in_password_stage
    click_link "Use a recovery code"
    fill_in "Recovery code", with: @recovery_codes.first
    click_button "Use recovery code"
    assert_text "Email, password, or verification code is invalid."
  end

  test "reset request response stays generic" do
    visit new_admin_password_reset_path
    fill_in "Email", with: @user.email

    perform_enqueued_jobs { click_button "Send reset link" }

    assert_current_path new_admin_session_path
    assert_text "If that email is the owner account, a reset link has been sent."
  end

  test "authentication pages fit a 320 pixel viewport" do
    page.current_window.resize_to(320, 720)
    visit new_admin_session_path

    overflow = page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")
    assert_equal false, overflow
    assert_button "Continue"
    assert_link "Forgot password?"
  end

  private

  def sign_in_password_stage
    visit new_admin_session_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: TEST_PASSWORD
    click_button "Continue"
  end
end
