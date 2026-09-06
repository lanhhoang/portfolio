class PublicController < ApplicationController
  SUPPORTED_LOCALES = %w[en fr vi].freeze

  around_action :with_locale, except: :root
  helper_method :current_locale

  def root
    redirect_to localized_root_path(locale: preferred_locale)
  end

  def current_locale
    @current_locale || I18n.default_locale.to_s
  end

  def default_url_options
    action_name == "root" ? {} : { locale: current_locale }
  end

  private

  def with_locale(&action)
    @current_locale = params.fetch(:locale)
    cookies.permanent[:portfolio_locale] = {
      value: @current_locale,
      same_site: :lax
    }
    I18n.with_locale(@current_locale, &action)
  end

  def preferred_locale
    saved_locale || requested_locale || I18n.default_locale.to_s
  end

  def saved_locale
    cookies[:portfolio_locale].presence_in(SUPPORTED_LOCALES)
  end

  def requested_locale
    request.get_header("HTTP_ACCEPT_LANGUAGE").to_s
      .split(",")
      .each_with_index
      .filter_map do |entry, index|
        language_range, *parameters = entry.strip.split(";")
        locale = language_range.downcase.split("-").first
        next unless locale.in?(SUPPORTED_LOCALES)

        quality_parameter = parameters.find { |parameter| parameter.strip.start_with?("q=") }
        quality = quality_parameter ? Float(quality_parameter.split("=", 2).last, exception: false).to_f : 1.0
        next unless quality.positive? && quality <= 1.0

        [ locale, quality, index ]
      end
      .max_by { |_locale, quality, index| [ quality, -index ] }
      &.first
  end
end
