# frozen_string_literal: true

class ErrorsController < PublicController
  skip_around_action :with_locale
  around_action :with_error_locale

  def show
    @locale_switch_paths = SUPPORTED_LOCALES.index_with do |locale|
      localized_root_path(locale: locale)
    end
    code = params.expect(:code).to_i

    render :show, status: code, formats: :html, locals: { code: code }
  end

  private

  def with_error_locale(&action)
    @current_locale = original_path_locale || preferred_locale
    I18n.with_locale(@current_locale, &action)
  end

  def original_path_locale
    locale = request.get_header("action_dispatch.original_path").to_s.split("/").second
    if locale.in?(SUPPORTED_LOCALES)
      locale
    end
  end
end
