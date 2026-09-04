# frozen_string_literal: true

class TagTranslation < ApplicationRecord
  belongs_to :tag, inverse_of: :translations

  validates :locale, inclusion: { in: %w[en fr vi] }, uniqueness: { scope: :tag_id }
  validates :name, :slug, presence: true
  validates :slug, uniqueness: { scope: :locale }
  validates :slug, format: {
    with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
    message: "must use lowercase letters, numbers, and single hyphens"
  }

  before_validation :set_initial_slug, on: :create

  def complete?
    name.present?
  end

  private

  def set_initial_slug
    self.slug = name.to_s.parameterize if slug.blank?
  end
end
