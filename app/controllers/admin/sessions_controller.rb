class Admin::SessionsController < Admin::AuthenticationController
  rate_limit to: 5, within: 15.minutes, only: :create,
    with: -> {
      flash.now[:alert] = "Too many attempts. Try again later."
      render :new, status: :too_many_requests
    }

  def new
    return redirect_to admin_root_path if Current.admin_user
    redirect_to admin_totp_challenge_path if Current.admin_session&.pending_totp?
  end

  def create
    user = AdminUser.authenticate_by(params.expect(admin_login: %i[email password]))

    if user
      start_new_admin_session_for(user, state: :pending_totp)
      redirect_to admin_totp_challenge_path
    else
      flash.now[:alert] = "Email, password, or verification code is invalid."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    terminate_admin_session
    redirect_to new_admin_session_path, notice: "Signed out.", status: :see_other
  end
end
