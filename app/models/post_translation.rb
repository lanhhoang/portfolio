# frozen_string_literal: true

class PostTranslation < ApplicationRecord
  include PublishableTranslation

  belongs_to :post, inverse_of: :translations

  before_validation :render_body_html, if: :will_save_change_to_body_markdown?

  before_validation :refresh_search_text

  enum :state, { draft: "draft", scheduled: "scheduled", published: "published" }, validate: true

  validates :locale, inclusion: { in: %w[en fr vi] }, uniqueness: { scope: :post_id }
  validates :title, :slug, :excerpt, :body_markdown, presence: true
  validates :slug, uniqueness: { scope: :locale }
  validates :slug, format: {
    with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
    message: "must use lowercase letters, numbers, and single hyphens"
  }
  validates :scheduled_at, presence: true, if: :scheduled?
  validates :published_at, presence: true, if: :published?

  before_validation :set_initial_slug, on: :create

  def complete?
    title.present? && excerpt.present? && body_markdown.present?
  end

  def publication_parent
    post
  end

  scope :publicly_visible, ->(locale:) {
    where(locale: locale.to_s, state: "published").where("published_at <= ?", Time.current)
  }

  def self.filtered(locale:, query:, tag_slug:)
    locale = locale.to_s
    query = SearchText.normalize(query.to_s.strip)
    tag_slug = tag_slug.to_s.strip
    relation = publicly_visible(locale: locale)
    relation = relation.where(
      "search_text LIKE :pattern ESCAPE '\\'",
      pattern: "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    ) if query.present?
    relation = relation
      .joins(post: { tags: :translations })
      .where(
        taggings: { taggable_type: "Post" },
        tag_translations: { locale: locale, slug: tag_slug }
      ) if tag_slug.present?
    relation.distinct.order(published_at: :desc)
  end

  private

  def set_initial_slug
    self.slug = title.to_s.parameterize if slug.blank?
  end

  def render_body_html
    self.body_html = MarkdownRenderer.call(body_markdown)
  end

  def refresh_search_text
    self.search_text = SearchText.normalize([ title, excerpt, body_markdown ].join(" "))
  end
end
