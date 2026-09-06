# frozen_string_literal: true

class ContactMailer < ApplicationMailer
  def owner_notification(contact_message)
    @contact_message = contact_message

    mail(
      to: Profile.current.public_contact_email,
      from: ENV.fetch("MAILER_FROM", "portfolio@example.test"),
      reply_to: contact_message.sender_email,
      subject: "[Portfolio contact] #{contact_message.subject}"
    )
  end
end
