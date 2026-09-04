# frozen_string_literal: true

class Resume < ApplicationRecord
  has_many :translations, class_name: "ResumeTranslation",
    inverse_of: :resume, dependent: :destroy, autosave: true

  accepts_nested_attributes_for :translations, allow_destroy: true,
    reject_if: ->(attributes) {
      attributes["locale"] != "en" && attributes["id"].blank? &&
        attributes.values_at("title", "description").all?(&:blank?)
    }

  validates :updated_on, presence: true
  validate :english_translation_present

  def self.current
    find_by(singleton_guard: 1)
  end

  private

  def english_translation_present
    return if translations.reject(&:marked_for_destruction?).any? { |translation| translation.locale == "en" }

    errors.add(:translations, "must include English")
  end
end
