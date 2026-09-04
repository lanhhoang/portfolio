class Admin::PasswordResetsController < Admin::AuthenticationController
  GENERIC_NOTICE = "If that email is the owner account, a reset link has been sent."

  rate_limit to: 3, within: 1.hour, only: :create,
    with: -> { redirect_to new_admin_session_path, notice: GENERIC_NOTICE }

  def new
  end

  def create
    email = params.expect(password_reset: [ :email ])[:email]
    if (user = AdminUser.find_by(email: email))
      AdminPasswordMailer.reset(user).deliver_later
    end

    redirect_to new_admin_session_path, notice: GENERIC_NOTICE
  end

  def edit
    @admin_user = AdminUser.new
  end

  def update
    @token = params[:token].to_s
    return redirect_for_invalid_token unless (@admin_user = reset_user(@token))

    if @admin_user.reset_password(password_params)
      redirect_to new_admin_session_path, notice: "Password reset. Sign in with your new password and verification code."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def reset_user(token)
    AdminUser.find_by_password_reset_token(token)
  end

  def password_params
    params.expect(admin_password_reset: %i[password password_confirmation])
  end

  def redirect_for_invalid_token
    redirect_to new_admin_password_reset_path, alert: "This reset code is invalid or expired."
  end
end
