# frozen_string_literal: true

class Profile < ApplicationRecord
  include PortfolioAttachmentValidations

  ACCENTS = %w[brown green lime orange yellow].freeze

  has_one_attached :portrait

  validates_portfolio_attachment :portrait,
    content_types: PortfolioAttachmentValidations::IMAGE_TYPES, extensions: %w[jpg jpeg png webp], max_size: 10.megabytes,
    type_message: "must be a JPEG, PNG, or WebP image"
  has_many :translations, class_name: "ProfileTranslation",
    inverse_of: :profile, dependent: :destroy, autosave: true

  validates :public_contact_email, presence: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :social_links_are_http_urls
  validates :accent, inclusion: { in: ACCENTS }
  validate :english_translation_present

  def self.current
    find_by(singleton_guard: 1)
  end

  private

  def social_links_are_http_urls
    unless social_links.is_a?(Hash)
      errors.add(:social_links, "must contain HTTP(S) URLs with a host")
      return
    end

    social_links.each_value do |value|
      uri = URI.parse(value.to_s)
      errors.add(:social_links, "must contain HTTP(S) URLs with a host") unless uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      errors.add(:social_links, "must contain HTTP(S) URLs with a host")
    end
  end

  def english_translation_present
    return if translations.reject(&:marked_for_destruction?).any? { |translation| translation.locale == "en" }

    errors.add(:translations, "must include English")
  end
end
