module AdminAuthenticationTestHelper
  TEST_PASSWORD = "correct horse battery staple"
  TEST_TOTP_SECRET = "JBSWY3DPEHPK3PXP"

  def sign_in_as_admin
    user = admin_users(:owner)
    post admin_session_path, params: {
      admin_login: { email: user.email, password: TEST_PASSWORD }
    }
    post admin_totp_challenge_path, params: {
      totp: { code: ROTP::TOTP.new(user.totp_secret).now }
    }
    user
  end

  def sign_out_admin
    delete admin_session_path
  end

  def sign_in_owner
    user = admin_users(:owner)
    visit new_admin_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: TEST_PASSWORD
    click_button "Continue"
    fill_in "Six-digit code", with: ROTP::TOTP.new(user.totp_secret).now
    click_button "Verify"
    user
  end
end
