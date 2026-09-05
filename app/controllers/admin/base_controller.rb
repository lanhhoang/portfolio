class Admin::BaseController < Admin::AuthenticationController
  layout "admin"
  before_action :require_admin!

  protected

  ADMIN_LOCALES = %w[en fr vi].freeze

  def prepare_translations(record)
    existing = record.translations.map(&:locale)
    (ADMIN_LOCALES - existing).each { |locale| record.translations.build(locale:) }
  end

  def protect_translation_locales(attributes)
    attributes[:translations_attributes]&.each_value do |translation|
      translation.delete(:locale) if translation[:id].present?
    end
    attributes
  end

  private

  def require_admin!
    return if Current.admin_user

    if Current.admin_session&.pending_totp?
      redirect_to admin_totp_challenge_path, alert: "Complete verification to continue."
    else
      redirect_to new_admin_session_path, alert: "Sign in to continue."
    end
  end
end
