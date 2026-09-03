# frozen_string_literal: true

class TagTranslation < ApplicationRecord
  belongs_to :tag, inverse_of: :translations

  validates :locale, inclusion: { in: %w[en fr vi] }, uniqueness: { scope: :tag_id }
  validates :name, :slug, presence: true
  validates :slug, uniqueness: { scope: :locale }
end
