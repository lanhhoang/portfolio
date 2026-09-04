module Admin::Authentication
  extend ActiveSupport::Concern

  included do
    before_action :resume_admin_session
    helper_method :current_admin_user
  end

  private

  def resume_admin_session
    raw_cookie = cookies[AdminSession::COOKIE_NAME]
    session_id = cookies.signed[AdminSession::COOKIE_NAME]
    Current.admin_session = AdminSession.active.includes(:admin_user).find_by(id: session_id)
    delete_admin_cookie if raw_cookie.present? && Current.admin_session.nil?
  end

  def current_admin_user
    Current.admin_user
  end

  def start_new_admin_session_for(admin_user, state:)
    Current.admin_session&.destroy!
    Current.admin_session = nil
    delete_admin_cookie
    reset_session

    record = admin_user.admin_sessions.create!(state: state)
    cookies.signed[AdminSession::COOKIE_NAME] = {
      value: record.id,
      expires: record.expires_at,
      httponly: true,
      secure: Rails.env.production? || request.ssl?,
      same_site: :strict,
      path: "/admin"
    }
    Current.admin_session = record
  end

  def terminate_admin_session
    Current.admin_session&.destroy!
    Current.admin_session = nil
    delete_admin_cookie
    reset_session
  end

  def delete_admin_cookie
    cookies.delete(
      AdminSession::COOKIE_NAME,
      secure: Rails.env.production? || request.ssl?,
      same_site: :strict,
      path: "/admin"
    )
  end
end
