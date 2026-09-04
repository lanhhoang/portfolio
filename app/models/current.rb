class Current < ActiveSupport::CurrentAttributes
  attribute :admin_session

  def admin_user
    admin_session&.verified? ? admin_session.admin_user : nil
  end
end
