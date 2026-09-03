# frozen_string_literal: true

class Project < ApplicationRecord
  include PortfolioAttachmentValidations

  has_one_attached :cover_image
  has_many_attached :gallery_images

  validates_portfolio_attachment :cover_image,
    content_types: PortfolioAttachmentValidations::IMAGE_TYPES, extensions: %w[jpg jpeg png webp], max_size: 10.megabytes,
    type_message: "must be a JPEG, PNG, or WebP image"
  validates_portfolio_attachment :gallery_images,
    content_types: PortfolioAttachmentValidations::IMAGE_TYPES, extensions: %w[jpg jpeg png webp], max_size: 10.megabytes,
    type_message: "must be a JPEG, PNG, or WebP image"

  has_many :translations, class_name: "ProjectTranslation",
    inverse_of: :project, dependent: :destroy, autosave: true
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  validates :role, presence: true
  validates :featured_position, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :links_are_http_urls
  validate :english_translation_present

  private

  def links_are_http_urls
    %i[live_url source_url].each do |attribute|
      next if public_send(attribute).blank?

      uri = URI.parse(public_send(attribute))
      errors.add(attribute, "must be an HTTP(S) URL with a host") unless uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      errors.add(attribute, "must be an HTTP(S) URL with a host")
    end
  end

  def english_translation_present
    return if translations.reject(&:marked_for_destruction?).any? { |translation| translation.locale == "en" }

    errors.add(:translations, "must include English")
  end
end
