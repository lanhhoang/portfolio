# frozen_string_literal: true

require "test_helper"

class ContactMailerTest < ActionMailer::TestCase
  test "builds a multipart owner notification" do
    Profile.create!(
      public_contact_email: "owner@example.test",
      translations_attributes: {
        "0" => {
          locale: "en", display_name: "Owner", headline: "Portfolio",
          introduction: "Introduction", biography_markdown: "Biography", availability_label: "Available"
        }
      }
    )
    message = ContactMessage.new(
      sender_name: "Ada Lovelace",
      sender_email: "ada@example.test",
      subject: "Project enquiry",
      body: "Could we work together?"
    )

    email = ContactMailer.owner_notification(message)

    assert_equal ["owner@example.test"], email.to
    assert_equal ["portfolio@example.test"], email.from
    assert_equal ["ada@example.test"], email.reply_to
    assert_equal "[Portfolio contact] Project enquiry", email.subject
    assert_includes email.text_part.body.decoded, "Could we work together?"
    assert_includes email.html_part.body.decoded, "Could we work together?"
  end
end
