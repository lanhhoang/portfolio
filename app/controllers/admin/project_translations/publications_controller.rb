# frozen_string_literal: true

class Admin::ProjectTranslations::PublicationsController < Admin::BaseController
  before_action :set_translation

  def create
    @translation.publish
    redirect_to edit_admin_project_path(@translation.project), notice: "#{@translation.title} was published", status: :see_other
  rescue PublishableTranslation::EnglishMustBePublished => error
    redirect_to edit_admin_project_path(@translation.project), alert: error.message, status: :see_other
  end

  def update
    @translation.schedule(at: scheduled_at)
    redirect_to edit_admin_project_path(@translation.project), notice: "#{@translation.title} was scheduled", status: :see_other
  rescue PublishableTranslation::InvalidScheduleTime, ArgumentError
    redirect_to edit_admin_project_path(@translation.project), alert: "Choose a future publication time", status: :see_other
  end

  def destroy
    @translation.unpublish
    redirect_to edit_admin_project_path(@translation.project), notice: "#{@translation.title} was unpublished", status: :see_other
  end

  private

  def set_translation
    @translation = ProjectTranslation.find(params[:project_translation_id])
  end

  def scheduled_at
    values = params.expect(publication: [:scheduled_at, :scheduled_at_local])
    if values[:scheduled_at].present?
      raise ArgumentError unless values[:scheduled_at].end_with?("Z")

      return Time.iso8601(values[:scheduled_at])
    end
    return Time.strptime(values[:scheduled_at_local], "%Y-%m-%dT%H:%M").utc if values[:scheduled_at_local].present?
  end
end
