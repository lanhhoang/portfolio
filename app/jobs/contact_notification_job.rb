# frozen_string_literal: true

class ContactNotificationJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(contact_message_id) { contact_message_id }, duration: 10.minutes

  def perform(contact_message_id)
    ContactMessage.find_by(id: contact_message_id)&.notify_owner_now
  end
end
