# frozen_string_literal: true

module ApplicationHelper
  def site_name
    @site_name ||= if controller_path == "errors"
      t("site.name")
    else
      Profile.current&.translations&.find_by(locale: I18n.locale.to_s)&.display_name.presence || t("site.name")
    end
  end

  def locale_switch_path(locale)
    return @locale_switch_paths[locale] if instance_variable_defined?(:@locale_switch_paths)

    url_for(only_path: true, locale: locale)
  end
end
