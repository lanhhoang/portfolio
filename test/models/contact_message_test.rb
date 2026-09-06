# frozen_string_literal: true

require "test_helper"

class ContactMessageTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
  end

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

  test "enqueues only after a new message commits" do
    message = valid_message

    assert_enqueued_with(job: ContactNotificationJob) do
      message.save!
    end
    assert_equal [message.id], enqueued_jobs.last.fetch(:args)
  end

  test "an enqueue failure preserves the committed message as failed" do
    error = SolidQueue::Job::EnqueueError.new("queue included private-message-body")

    stub_method(ContactNotificationJob, :perform_later, ->(*) { raise error }) do
      assert_nothing_raised { valid_message.save! }
    end

    message = ContactMessage.order(:id).last
    assert message.failed?
    assert_equal "SolidQueue::Job::EnqueueError: delivery failed", message.last_delivery_error
    assert_not_includes message.last_delivery_error, "private-message-body"
  end

  test "retry transitions failed to pending once and enqueues once" do
    message = valid_message.tap(&:save!)
    clear_enqueued_jobs
    message.update!(email_delivery_state: :failed, last_delivery_error: "TimeoutError: delivery failed")

    assert_enqueued_with(job: ContactNotificationJob, args: [message.id]) do
      assert message.retry_delivery_later
    end
    assert message.reload.pending?
    assert_nil message.last_delivery_error

    assert_no_enqueued_jobs do
      assert_equal false, message.retry_delivery_later
    end
  end

  test "delivered messages cannot be requeued" do
    message = valid_message.tap(&:save!)
    clear_enqueued_jobs
    message.update!(email_delivery_state: :delivered, delivered_at: Time.current)

    assert_no_enqueued_jobs do
      assert_equal false, message.retry_delivery_later
    end
  end

  test "retry returns to failed when queue insertion raises" do
    message = valid_message.tap(&:save!)
    clear_enqueued_jobs
    message.update!(email_delivery_state: :failed, last_delivery_error: "TimeoutError: delivery failed")

    error = SolidQueue::Job::EnqueueError.new("queue unavailable")
    stub_method(ContactNotificationJob, :perform_later, ->(*) { raise error }) do
      assert_equal false, message.retry_delivery_later
    end

    assert message.reload.failed?
    assert_equal "SolidQueue::Job::EnqueueError: delivery failed", message.last_delivery_error
  end
end
