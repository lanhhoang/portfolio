# frozen_string_literal: true

module PublishableTranslation
  extend ActiveSupport::Concern

  class EnglishMustBePublished < StandardError; end
  class InvalidScheduleTime < StandardError; end

  included do
    scope :due, ->(at = Time.current) { scheduled.where(scheduled_at: ..at) }
    scope :upcoming, ->(at = Time.current) { scheduled.where("scheduled_at > ?", at) }

    validate :english_is_published_before_optional_locale, if: :publishing_optional_locale?
  end

  def publish
    with_lock do
      return self if published?

      raise EnglishMustBePublished, "Publish the English translation first" unless publishable?

      update!(state: :published, scheduled_at: nil, published_at: Time.current)
    end

    self
  end

  def schedule(at:)
    raise InvalidScheduleTime, "Choose a future publication time" unless at && at > Time.current

    with_lock do
      update!(state: :scheduled, scheduled_at: at, published_at: nil)
    end

    self
  end

  def unpublish
    with_lock do
      return self if draft?

      update!(state: :draft, scheduled_at: nil, published_at: nil)
    end

    self
  end

  def publishable?
    locale == "en" || publication_parent.translations.published.exists?(locale: "en")
  end

  private

  def publishing_optional_locale?
    locale != "en" && published? && will_save_change_to_state?
  end

  def english_is_published_before_optional_locale
    errors.add(:state, "requires the English translation to be published first") unless publishable?
  end
end
