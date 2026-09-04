class Admin::RecoveryChallengesController < Admin::AuthenticationController
  before_action :require_pending_session
  rate_limit to: 5, within: 10.minutes, only: :create,
    by: -> { request.remote_ip },
    with: -> {
      flash.now[:alert] = "Too many attempts. Try again later."
      render :show, status: :too_many_requests
    }

  def show
  end

  def create
    user = Current.admin_session.admin_user

    if user.consume_recovery_code(params.expect(recovery: [:code])[:code])
      start_new_admin_session_for(user, state: :verified)
      redirect_to admin_root_path, notice: "Signed in. Generate replacement recovery codes after access is restored."
    else
      flash.now[:alert] = "Email, password, or verification code is invalid."
      render :show, status: :unprocessable_entity
    end
  end
end
