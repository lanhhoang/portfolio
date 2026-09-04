class Admin::BaseController < Admin::AuthenticationController
  layout "admin"
  before_action :require_admin!

  private

  def require_admin!
    return if Current.admin_user

    if Current.admin_session&.pending_totp?
      redirect_to admin_totp_challenge_path, alert: "Complete verification to continue."
    else
      redirect_to new_admin_session_path, alert: "Sign in to continue."
    end
  end
end
