# frozen_string_literal: true

class ContactMessage < ApplicationRecord
  enum :state, { unread: "unread", read: "read", archived: "archived" }, default: :unread, validate: true
  enum :email_delivery_state,
    { pending: "pending", delivered: "delivered", failed: "failed" },
    default: :pending,
    validate: true

  validates :sender_name, presence: true, length: { maximum: 120 }
  validates :sender_email,
    presence: true,
    length: { maximum: 254 },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :subject, presence: true, length: { maximum: 200 }
  validates :body, presence: true, length: { maximum: 10_000 }
  validates :last_delivery_error, length: { maximum: 255 }, allow_nil: true
end
