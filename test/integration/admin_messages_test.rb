# frozen_string_literal: true

require "test_helper"

class AdminMessagesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @message = ContactMessage.create!(
      sender_name: "Ada Lovelace",
      sender_email: "ada@example.test",
      subject: "Project enquiry",
      body: "Original private body"
    )
    clear_enqueued_jobs
  end

  test "requires an authenticated owner" do
    get admin_messages_path
    assert_response :redirect
  end

  test "lists and shows message state on a mobile card" do
    sign_in_as_admin

    get admin_messages_path
    assert_response :success
    assert_select "article[data-message-id='#{@message.id}']"
    assert_includes response.body, "Project enquiry"

    get admin_message_path(@message)
    assert_response :success
    assert_includes response.body, "Original private body"
  end

  test "updates inbox state through the state resource" do
    sign_in_as_admin

    patch admin_message_state_path(@message), params: { state: "read" }
    assert @message.reload.read?

    patch admin_message_state_path(@message), params: { state: "unread" }
    assert @message.reload.unread?

    patch admin_message_state_path(@message), params: { state: "archived" }
    assert @message.reload.archived?

    get admin_messages_path
    assert_select "article[data-message-id='#{@message.id}']", count: 0

    get admin_messages_path(state: :archived)
    assert_select "article[data-message-id='#{@message.id}']"
  end

  test "rejects an invalid inbox state" do
    sign_in_as_admin

    patch admin_message_state_path(@message), params: { state: "deleted" }

    assert_response :unprocessable_entity
    assert @message.reload.unread?
  end

  test "failed delivery retry is idempotent and preserves the message" do
    sign_in_as_admin
    @message.update!(email_delivery_state: :failed, last_delivery_error: "RuntimeError: delivery failed")
    original = @message.attributes.slice("sender_name", "sender_email", "subject", "body", "created_at")

    assert_enqueued_with(job: ContactNotificationJob, args: [ @message.id ]) do
      post admin_message_delivery_retry_path(@message)
    end
    assert @message.reload.pending?
    assert_equal original, @message.attributes.slice("sender_name", "sender_email", "subject", "body", "created_at")

    assert_no_enqueued_jobs do
      post admin_message_delivery_retry_path(@message)
    end
  end
end
