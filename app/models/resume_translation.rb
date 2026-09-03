# frozen_string_literal: true

class ResumeTranslation < ApplicationRecord
  include PortfolioAttachmentValidations

  belongs_to :resume, inverse_of: :translations
  has_one_attached :pdf

  validates_portfolio_attachment :pdf,
    content_types: %w[application/pdf], extensions: %w[pdf], max_size: 5.megabytes,
    type_message: "must be a PDF"

  validates :locale, inclusion: { in: %w[en fr vi] }, uniqueness: { scope: :resume_id }
  validates :title, :description, presence: true
end
