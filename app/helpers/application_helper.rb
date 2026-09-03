# frozen_string_literal: true

module ApplicationHelper
  def locale_switch_path(locale)
    @locale_switch_paths ||= {}
    @locale_switch_paths[locale] || url_for(only_path: true, locale: locale)
  end
end
