class AdminSession < ApplicationRecord
  COOKIE_NAME = :admin_session
  PENDING_LIFETIME = 10.minutes
  VERIFIED_LIFETIME = 12.hours

  belongs_to :admin_user

  enum :state, { pending_totp: "pending_totp", verified: "verified" }, validate: true

  validates :expires_at, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }

  before_validation :set_expiration, on: :create

  private

  def set_expiration
    self.expires_at ||= (verified? ? VERIFIED_LIFETIME : PENDING_LIFETIME).from_now
  end
end
