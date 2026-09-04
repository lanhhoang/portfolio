require "test_helper"

class Admin::AuthenticationTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Rails.cache.clear
    @user = admin_users(:owner)
    @recovery_codes = @user.replace_recovery_codes
  end

  teardown do
    Rails.cache.clear
    Current.reset
  end

  test "anonymous and password-only requests cannot enter admin" do
    get admin_root_path
    assert_redirected_to new_admin_session_path

    post admin_session_path, params: { admin_login: { email: @user.email, password: TEST_PASSWORD } }
    assert_redirected_to admin_totp_challenge_path

    get admin_root_path
    assert_redirected_to admin_totp_challenge_path
    assert_nil Current.admin_user
  end

  test "shared request helper completes both authentication stages" do
    sign_in_as_admin

    assert_predicate AdminSession.find(signed_admin_session_id), :verified?
    get admin_root_path
    assert_response :success
  end

  test "invalid email and invalid password return the same response" do
    post admin_session_path, params: { admin_login: { email: "missing@example.com", password: TEST_PASSWORD } }
    missing_status = response.status
    missing_message = flash[:alert]

    post admin_session_path, params: { admin_login: { email: @user.email, password: "wrong password value" } }

    assert_equal missing_status, response.status
    assert_equal missing_message, flash[:alert]
    assert_equal "Email, password, or verification code is invalid.", flash[:alert]
  end

  test "fresh TOTP rotates the pending session into a verified session" do
    post admin_session_path, params: { admin_login: { email: @user.email, password: TEST_PASSWORD } }
    pending_cookie = cookies[AdminSession::COOKIE_NAME]
    pending = AdminSession.find(signed_admin_session_id)
    assert_predicate pending, :pending_totp?

    code = ROTP::TOTP.new(TEST_TOTP_SECRET).at(Time.current)
    post admin_totp_challenge_path, params: { totp: { code: code } }

    assert_redirected_to admin_root_path
    verified_cookie = cookies[AdminSession::COOKIE_NAME]
    verified = AdminSession.find(signed_admin_session_id)
    assert_not_equal pending_cookie, verified_cookie
    assert_not AdminSession.exists?(pending.id)
    assert_predicate verified, :verified?

    get admin_root_path
    assert_response :success
  end

  test "TOTP replay cannot create a second verified session" do
    code = ROTP::TOTP.new(TEST_TOTP_SECRET).at(Time.current)
    sign_in_with_password
    post admin_totp_challenge_path, params: { totp: { code: code } }
    delete admin_session_path

    sign_in_with_password
    post admin_totp_challenge_path, params: { totp: { code: code } }

    assert_response :unprocessable_entity
    assert_equal "Email, password, or verification code is invalid.", flash[:alert]
    assert_predicate AdminSession.find(signed_admin_session_id), :pending_totp?
  end

  test "recovery code is one-use and rotates into a verified session" do
    sign_in_with_password
    post admin_recovery_challenge_path, params: { recovery: { code: @recovery_codes.first } }

    assert_redirected_to admin_root_path
    assert_predicate AdminSession.find(signed_admin_session_id), :verified?
    assert_equal 9, @user.reload.recovery_code_digests.length

    delete admin_session_path
    sign_in_with_password
    post admin_recovery_challenge_path, params: { recovery: { code: @recovery_codes.first } }
    assert_response :unprocessable_entity
  end

  test "logout destroys the database session and cookie" do
    sign_in_with_totp
    session_id = signed_admin_session_id

    delete admin_session_path

    assert_response :see_other
    assert_redirected_to new_admin_session_path
    assert_not AdminSession.exists?(session_id)
    get admin_root_path
    assert_redirected_to new_admin_session_path
  end

  test "tampered signed cookie fails closed" do
    sign_in_with_totp
    cookies[AdminSession::COOKIE_NAME] = "#{cookies[AdminSession::COOKIE_NAME]}tampered"

    get admin_root_path

    assert_redirected_to new_admin_session_path
  end

  test "malformed scoped parameters return bad request without creating a session" do
    assert_no_difference -> { AdminSession.count } do
      post admin_session_path, params: { admin_login: "not-an-object" }
    end

    assert_response :bad_request
  end

  test "expired pending and verified sessions fail closed" do
    sign_in_with_password
    travel 11.minutes
    get admin_totp_challenge_path
    assert_redirected_to new_admin_session_path

    travel_back
    sign_in_with_totp
    travel 13.hours
    get admin_root_path
    assert_redirected_to new_admin_session_path
  end

  test "password attempts are throttled after five failures" do
    5.times do
      post admin_session_path, params: { admin_login: { email: @user.email, password: "incorrect password" } }
      assert_response :unprocessable_entity
    end

    post admin_session_path, params: { admin_login: { email: @user.email, password: "incorrect password" } }
    assert_response :too_many_requests
  end

  test "TOTP attempts are throttled per IP" do
    sign_in_with_password
    5.times do
      post admin_totp_challenge_path, params: { totp: { code: "000000" } }
      assert_response :unprocessable_entity
    end

    post admin_totp_challenge_path, params: { totp: { code: "000000" } }
    assert_response :too_many_requests
  end

  test "recovery attempts are throttled per IP" do
    sign_in_with_password
    5.times do
      post admin_recovery_challenge_path, params: { recovery: { code: "AAAA-BBBB-CCCC-DDDD-0000" } }
      assert_response :unprocessable_entity
    end

    post admin_recovery_challenge_path, params: { recovery: { code: "AAAA-BBBB-CCCC-DDDD-0000" } }
    assert_response :too_many_requests
  end

  test "HTTPS auth cookie is secure strict and HTTP only" do
    https!
    post admin_session_path, params: { admin_login: { email: @user.email, password: TEST_PASSWORD } }
    # reset_session emits a second Set-Cookie header, so the header arrives as an Array;
    # Rails writes boolean flag names in lowercase, so compare case-insensitively
    set_cookie = Array(response.headers["Set-Cookie"]).join("\n").downcase

    assert_includes set_cookie, "admin_session="
    assert_includes set_cookie, "path=/admin"
    assert_includes set_cookie, "httponly"
    assert_includes set_cookie, "samesite=strict"
    assert_includes set_cookie, "secure"
  end

  test "there is no registration route" do
    get "/admin/users/new"
    assert_response :not_found

    post "/admin/users"
    assert_response :not_found
  end

  private

  def signed_admin_session_id
    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar[AdminSession::COOKIE_NAME] = cookies[AdminSession::COOKIE_NAME]
    end.signed[AdminSession::COOKIE_NAME]
  end

  def sign_in_with_password
    post admin_session_path, params: { admin_login: { email: @user.email, password: TEST_PASSWORD } }
  end

  def sign_in_with_totp
    sign_in_with_password
    code = ROTP::TOTP.new(TEST_TOTP_SECRET).at(Time.current)
    post admin_totp_challenge_path, params: { totp: { code: code } }
  end
end
