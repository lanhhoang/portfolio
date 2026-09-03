# frozen_string_literal: true

class Post < ApplicationRecord
  include PortfolioAttachmentValidations

  has_one_attached :cover_image

  validates_portfolio_attachment :cover_image,
    content_types: PortfolioAttachmentValidations::IMAGE_TYPES, extensions: %w[jpg jpeg png webp], max_size: 10.megabytes,
    type_message: "must be a JPEG, PNG, or WebP image"

  has_many :translations, class_name: "PostTranslation",
    inverse_of: :post, dependent: :destroy, autosave: true
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  validate :english_translation_present

  private

  def english_translation_present
    return if translations.reject(&:marked_for_destruction?).any? { |translation| translation.locale == "en" }
    errors.add(:translations, "must include English")
  end
end
