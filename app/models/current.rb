class Current < ActiveSupport::CurrentAttributes
  attribute :admin_session

  def admin_user
    admin_session.admin_user if admin_session&.verified? && admin_session.expires_at.future?
  end
end
