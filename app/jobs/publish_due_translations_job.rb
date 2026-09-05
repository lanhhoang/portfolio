# frozen_string_literal: true

class PublishDueTranslationsJob < ApplicationJob
  queue_as :default

  def perform
    now = Time.current
    models = [ ProjectTranslation, PostTranslation ]
    models.each { |model| publish_scope(model.due(now).where(locale: "en"), at: now) }
    models.each { |model| publish_scope(model.due(now).where.not(locale: "en"), at: now) }
  end

  private

  def publish_scope(scope, at:)
    scope.find_each do |translation|
      begin
        translation.with_lock do
          translation.publish if translation.scheduled? && translation.scheduled_at <= at
        end
      rescue PublishableTranslation::EnglishMustBePublished
        next
      end
    end
  end
end
