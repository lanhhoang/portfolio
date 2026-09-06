# frozen_string_literal: true

require "test_helper"

class ContactNotificationJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    Profile.create!(
      public_contact_email: "owner@example.test",
      translations_attributes: {
        "0" => {
          locale: "en", display_name: "Owner", headline: "Portfolio",
          introduction: "Introduction", biography_markdown: "Biography", availability_label: "Available"
        }
      }
    )
    clear_enqueued_jobs
  end

  def create_message
    ContactMessage.create!(
      sender_name: "Ada Lovelace",
      sender_email: "ada@example.test",
      subject: "Project enquiry",
      body: "Private project details"
    )
  end

  test "delivers once and records success" do
    message = create_message
    clear_enqueued_jobs

    assert_emails 1 do
      ContactNotificationJob.perform_now(message.id)
      ContactNotificationJob.perform_now(message.id)
    end

    assert message.reload.delivered?
    assert_not_nil message.delivered_at
  end

  test "persists a safe failure and does not raise" do
    message = create_message
    delivery = Object.new
    delivery.define_singleton_method(:deliver_now!) do
      raise RuntimeError, "SMTP included Private project details"
    end

    stub_method(ContactMailer, :owner_notification, ->(*) { delivery }) do
      ContactNotificationJob.perform_now(message.id)
    end

    assert message.reload.failed?
    assert_equal "RuntimeError: delivery failed", message.last_delivery_error
    assert_not_includes message.last_delivery_error, message.body
  end

  test "missing messages are a no-op" do
    assert_nothing_raised do
      ContactNotificationJob.perform_now(-1)
    end
  end

  test "serialized arguments contain only the database id" do
    message = create_message
    serialized = ContactNotificationJob.new(message.id).serialize

    assert_equal [ message.id ], serialized.fetch("arguments")
    assert_not_includes serialized.to_json, message.body
  end
end
