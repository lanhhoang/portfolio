# frozen_string_literal: true

class Admin::DashboardController < Admin::BaseController
  TRANSLATION_MODELS = [ ProjectTranslation, PostTranslation ].freeze

  def show
    @project_count = Project.count
    @post_count = Post.count
    @tag_count = Tag.count
    @unread_message_count = ContactMessage.unread.count
    @failed_delivery_count = ContactMessage.failed.count
    now = Time.current

    @draft_translations = TRANSLATION_MODELS
      .flat_map { |model| model.draft.order(updated_at: :desc).limit(10).to_a }
      .sort_by(&:updated_at)
      .reverse
      .first(10)

    @upcoming_translations = TRANSLATION_MODELS
      .flat_map { |model| model.upcoming(now).order(:scheduled_at).limit(10).to_a }
      .sort_by(&:scheduled_at)
      .first(10)

    @failed_publications = TRANSLATION_MODELS
      .flat_map { |model| model.due(now).where.not(locale: "en").order(:scheduled_at).to_a }
      .reject(&:publishable?)
      .sort_by(&:scheduled_at)
      .first(10)
  end
end
