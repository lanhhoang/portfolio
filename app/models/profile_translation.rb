# frozen_string_literal: true

class ProfileTranslation < ApplicationRecord
  belongs_to :profile, inverse_of: :translations

  validates :locale, inclusion: { in: %w[en fr vi] }, uniqueness: { scope: :profile_id }
  validates :display_name, :headline, :introduction, :biography_markdown,
    :availability_label, presence: true
end
