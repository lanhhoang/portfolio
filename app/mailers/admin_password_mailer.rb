class AdminPasswordMailer < ApplicationMailer
  def reset(admin_user)
    @admin_user = admin_user
    @token = admin_user.password_reset_token
    @reset_url = edit_admin_password_reset_url
    mail(
      to: admin_user.email,
      from: ENV.fetch("MAILER_FROM", "portfolio@example.test"),
      subject: "Reset your portfolio admin password"
    )
  end
end
