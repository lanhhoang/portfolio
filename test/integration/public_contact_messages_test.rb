# frozen_string_literal: true

require "test_helper"

class PublicContactMessagesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    Rails.cache.clear
    clear_enqueued_jobs
  end

  teardown do
    Rails.cache.clear
  end

  def valid_params
    {
      contact_message: {
        sender_name: "Ada Lovelace",
        sender_email: "ada@example.test",
        subject: "Project enquiry",
        body: "Please contact me about a project.",
        website: ""
      }
    }
  end

  test "renders localized forms" do
    get localized_contact_path(locale: :en)
    assert_response :success
    assert_select "h1", "Contact"

    get localized_contact_path(locale: :fr)
    assert_response :success
    assert_select "h1", "Contactez-moi"

    get localized_contact_path(locale: :vi)
    assert_response :success
    assert_select "h1", "Liên hệ"
  end

  test "marks contact as the current navigation page" do
    get localized_contact_path(locale: :en)

    assert_select 'a[aria-current="page"]', text: "Contact"
  end

  test "renders localized validation messages" do
    params = valid_params
    params[:contact_message][:sender_email] = "invalid"

    post localized_contact_path(locale: :fr), params: params

    assert_response :unprocessable_entity
    assert_includes response.body, "n’est pas valide"
  end

  test "persists before returning receipt feedback and enqueues one id-only job" do
    assert_difference("ContactMessage.count", 1) do
      assert_enqueued_with(job: ContactNotificationJob) do
        post localized_contact_path(locale: :en), params: valid_params
      end
    end

    message = ContactMessage.order(:id).last
    assert_redirected_to localized_contact_path(locale: :en)
    follow_redirect!
    assert_includes response.body, "Your message has been saved."
    assert message.pending?
    assert_equal [message.id], enqueued_jobs.last.fetch(:args)
  end

  test "invalid input renders field errors without persistence or mail" do
    params = valid_params
    params[:contact_message][:sender_email] = "invalid"

    assert_no_difference("ContactMessage.count") do
      assert_no_enqueued_jobs do
        post localized_contact_path(locale: :en), params: params
      end
    end

    assert_response :unprocessable_entity
    assert_select "input[value='Ada Lovelace']"
    assert_includes response.body, "is invalid"
  end

  test "a filled honeypot is rejected without persistence or mail" do
    params = valid_params
    params[:contact_message][:website] = "https://spam.example"

    assert_no_difference("ContactMessage.count") do
      assert_no_enqueued_jobs do
        post localized_contact_path(locale: :en), params: params
      end
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "We could not accept that submission."
  end

  test "the sixth request from one IP is rate limited" do
    5.times do
      post localized_contact_path(locale: :en), params: valid_params, headers: { "REMOTE_ADDR" => "192.0.2.10" }
      assert_response :redirect
    end

    assert_no_difference("ContactMessage.count") do
      assert_no_enqueued_jobs do
        post localized_contact_path(locale: :en), params: valid_params, headers: { "REMOTE_ADDR" => "192.0.2.10" }
      end
    end

    assert_response :too_many_requests
    assert_includes response.body, "Too many messages were submitted. Please try again later."
  end

  test "message body parameters are filtered from logs" do
    filtered = ActiveSupport::ParameterFilter
      .new(Rails.application.config.filter_parameters)
      .filter(body: "private-message-body")

    assert_equal "[FILTERED]", filtered.fetch(:body)
    assert_includes ContactMessage.filter_attributes, :body
  end
end
