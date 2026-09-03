module ApplicationHelper
  def locale_switch_path(locale)
    url_for(only_path: true, locale: locale)
  end
end
