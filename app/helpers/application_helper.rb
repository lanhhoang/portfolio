# frozen_string_literal: true

module ApplicationHelper
  def locale_switch_path(locale)
    return @locale_switch_paths[locale] if instance_variable_defined?(:@locale_switch_paths)

    url_for(only_path: true, locale: locale)
  end
end
