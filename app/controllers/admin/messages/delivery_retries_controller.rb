# frozen_string_literal: true

class Admin::Messages::DeliveryRetriesController < Admin::BaseController
  def create
    message = ContactMessage.find(params[:message_id])

    if message.retry_delivery_later
      redirect_back fallback_location: admin_message_path(message), notice: "Email retry queued.", status: :see_other
    else
      redirect_back fallback_location: admin_message_path(message), alert: "Email could not be queued or is already pending or delivered.", status: :see_other
    end
  end
end
