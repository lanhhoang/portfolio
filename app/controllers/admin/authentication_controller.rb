class Admin::AuthenticationController < ApplicationController
  include Admin::Authentication

  layout "admin_authentication"

  private

  def require_pending_session
    return if Current.admin_session&.pending_totp?

    redirect_to new_admin_session_path, alert: "Sign in to continue."
  end
end
