# frozen_string_literal: true

require "test_helper"

class ContactMessageTest < ActiveSupport::TestCase
  def valid_message
    ContactMessage.new(
      sender_name: "Ada Lovelace",
      sender_email: "ada@example.test",
      subject: "Project enquiry",
      body: "Could we discuss a Rails project?"
    )
  end

  test "defaults to unread and pending" do
    message = valid_message
    message.save!

    assert message.unread?
    assert message.pending?
    assert_nil message.delivered_at
    assert_nil message.last_delivery_error
  end

  test "database rejects inconsistent delivery metadata" do
    message = valid_message.tap(&:save!)

    assert_raises ActiveRecord::StatementInvalid do
      message.update_columns(email_delivery_state: "delivered", delivered_at: nil)
    end
  end

  test "requires bounded sender fields and a valid email" do
    message = ContactMessage.new

    assert_not message.valid?
    assert message.errors.of_kind?(:sender_name, :blank)
    assert message.errors.of_kind?(:sender_email, :blank)
    assert message.errors.of_kind?(:subject, :blank)
    assert message.errors.of_kind?(:body, :blank)

    message.assign_attributes(
      sender_name: "A" * 121,
      sender_email: "not-an-email",
      subject: "S" * 201,
      body: "B" * 10_001
    )
    assert_not message.valid?
  end
end
