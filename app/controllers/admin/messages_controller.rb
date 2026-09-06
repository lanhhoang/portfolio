# frozen_string_literal: true

class Admin::MessagesController < Admin::BaseController
  def index
    scope = params[:state] == "archived" ? ContactMessage.archived : ContactMessage.where.not(state: :archived)
    @messages = scope.order(created_at: :desc)
  end

  def show
    @message = ContactMessage.find(params[:id])
  end
end
