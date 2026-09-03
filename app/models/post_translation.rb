# frozen_string_literal: true

class PostTranslation < ApplicationRecord
  belongs_to :post, inverse_of: :translations

  enum :state, { draft: "draft", scheduled: "scheduled", published: "published" }, validate: true

  validates :locale, inclusion: { in: %w[en fr vi] }, uniqueness: { scope: :post_id }
  validates :title, :slug, :excerpt, :body_markdown, presence: true
  validates :slug, uniqueness: { scope: :locale }
  validates :scheduled_at, presence: true, if: :scheduled?
  validates :published_at, presence: true, if: :published?

  scope :publicly_visible, ->(locale:) {
    where(locale: locale.to_s, state: "published").where("published_at <= ?", Time.current)
  }

  private
end
