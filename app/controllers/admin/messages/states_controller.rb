# frozen_string_literal: true

class Admin::Messages::StatesController < Admin::BaseController
  def update
    message = ContactMessage.find(params[:message_id])
    state = params.expect(:state)
    return head :unprocessable_entity unless state.in?(ContactMessage.states.keys)

    message.update!(state:)
    destination = message.archived? ? admin_messages_path : admin_message_path(message)
    redirect_to destination, notice: "Message marked as #{state}.", status: :see_other
  end
end
