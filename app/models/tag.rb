# frozen_string_literal: true

class Tag < ApplicationRecord
  has_many :translations, class_name: "TagTranslation",
    inverse_of: :tag, dependent: :destroy, autosave: true
  has_many :taggings, dependent: :destroy

  validate :english_translation_present

  private

  def english_translation_present
    return if translations.reject(&:marked_for_destruction?).any? { |translation| translation.locale == "en" }
    errors.add(:translations, "must include English")
  end
end
