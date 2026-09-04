require "test_helper"

class AdminPasswordMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers

  def default_url_options
    Rails.application.config.action_mailer.default_url_options
  end
  test "reset addresses only the owner and mints a usable expiring token while rendering" do
    user = admin_users(:owner)
    mail = AdminPasswordMailer.reset(user)
    text_body = mail.text_part.body.decoded
    token = text_body.match(/Enter this one-time reset code:\s*\n([^\s]+)/).captures.first

    assert_equal [user.email], mail.to
    assert_equal [ENV.fetch("MAILER_FROM", "portfolio@example.test")], mail.from
    assert_equal "Reset your portfolio admin password", mail.subject
    assert_match edit_admin_password_reset_url, text_body
    assert_match edit_admin_password_reset_url, mail.html_part.body.decoded
    assert_match token, text_body
    assert_match token, mail.html_part.body.decoded
    assert_equal user, AdminUser.find_by_password_reset_token(token)
    assert_no_match(/token=/, mail.body.encoded)
    assert_no_match TEST_PASSWORD, mail.body.encoded
    assert_no_match user.totp_secret, mail.body.encoded
  end
end
