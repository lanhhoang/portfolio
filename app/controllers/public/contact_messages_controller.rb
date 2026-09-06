# frozen_string_literal: true

module Public
  class ContactMessagesController < PublicController
    rate_limit to: 5,
      within: 10.minutes,
      only: :create,
      by: -> { request.remote_ip },
      with: -> { render_rate_limited }

    def new
      @contact_message = ContactMessage.new
    end

    def create
      @contact_message = ContactMessage.new(contact_message_params)

      if honeypot_filled?
        flash.now[:alert] = t("contact.spam_rejected")
        render :new, status: :unprocessable_entity
      elsif @contact_message.save
        redirect_to localized_contact_path(locale: I18n.locale), notice: t("contact.received")
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

      def contact_message_params
        params.expect(contact_message: %i[sender_name sender_email subject body])
      end

      def honeypot_filled?
        params.dig(:contact_message, :website).present?
      end

      def render_rate_limited
        @contact_message = ContactMessage.new(contact_message_params)
        flash.now[:alert] = t("contact.rate_limited")
        render :new, status: :too_many_requests
      end
  end
end
