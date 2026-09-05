# frozen_string_literal: true

class PublishDueTranslationsJob < ApplicationJob
  queue_as :default

  def perform
    now = Time.current
    models = [ProjectTranslation, PostTranslation]
    models.each { |model| publish_scope(model.due(now).where(locale: "en")) }
    models.each { |model| publish_scope(model.due(now).where.not(locale: "en")) }
  end

  private

  def publish_scope(scope)
    scope.find_each do |translation|
      begin
        translation.publish
      rescue PublishableTranslation::EnglishMustBePublished
        next
      end
    end
  end
end
