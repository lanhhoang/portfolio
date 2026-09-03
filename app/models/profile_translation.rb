# frozen_string_literal: true

class ProfileTranslation < ApplicationRecord
  belongs_to :profile, inverse_of: :translations

  before_validation :render_biography_html, if: :will_save_change_to_biography_markdown?

  validates :locale, inclusion: { in: %w[en fr vi] }, uniqueness: { scope: :profile_id }
  validates :display_name, :headline, :introduction, :biography_markdown,
    :availability_label, presence: true

  private

  def render_biography_html
    self.biography_html = MarkdownRenderer.call(biography_markdown)
  end
end
