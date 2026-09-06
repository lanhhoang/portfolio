# frozen_string_literal: true

class ContactMessage < ApplicationRecord
  enum :state, { unread: "unread", read: "read", archived: "archived" }, default: :unread, validate: true
  enum :email_delivery_state,
    { pending: "pending", delivered: "delivered", failed: "failed" },
    default: :pending,
    validate: true

  after_create_commit :notify_owner_later

  validates :sender_name, presence: true, length: { maximum: 120 }
  validates :sender_email,
    presence: true,
    length: { maximum: 254 },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :subject, presence: true, length: { maximum: 200 }
  validates :body, presence: true, length: { maximum: 10_000 }
  validates :last_delivery_error, length: { maximum: 255 }, allow_nil: true

  def notify_owner_later
    ContactNotificationJob.perform_later(id)
    true
  rescue SolidQueue::Job::EnqueueError => error
    record_delivery_failure(error)
    false
  end

  def notify_owner_now
    return if delivered?

    ContactMailer.owner_notification(self).deliver_now!
    record_delivery_success
  rescue StandardError => error
    record_delivery_failure(error) unless delivered?
  end

  def retry_delivery_later
    requeued = self.class.failed.where(id:).update_all(
      email_delivery_state: "pending",
      delivered_at: nil,
      last_delivery_error: nil,
      updated_at: Time.current
    ) == 1
    return false unless requeued

    reload
    notify_owner_later
  end

  private

    def record_delivery_success
      update!(
        email_delivery_state: :delivered,
        delivered_at: Time.current,
        last_delivery_error: nil
      )
    end

    def record_delivery_failure(error)
      error_class = error.class.name.to_s.gsub(/[^A-Za-z0-9_:]/, "").presence || "DeliveryError"
      update!(
        email_delivery_state: :failed,
        delivered_at: nil,
        last_delivery_error: "#{error_class}: delivery failed".truncate(255)
      )
    end
end
