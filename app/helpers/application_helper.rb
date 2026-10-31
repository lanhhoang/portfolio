# frozen_string_literal: true

module ApplicationHelper
  def site_name
    @site_name ||= if controller_path == "errors"
      t("site.name")
    else
      site_profile&.translations&.find_by(locale: I18n.locale.to_s)&.display_name.presence || t("site.name")
    end
  end

  def site_profile
    return @site_profile if defined?(@site_profile)

    @site_profile = (Profile.current unless controller_path == "errors")
  end

  # "2023", "2021–2023" or "2024–Present", each year wrapped in <time>.
  def project_timeline(project)
    started = time_tag(project.started_on, project.started_on.year)
    if project.ended_on.nil?
      safe_join([ started, t("public.projects.present") ], "–")
    elsif project.ended_on.year == project.started_on.year
      started
    else
      safe_join([ started, time_tag(project.ended_on, project.ended_on.year) ], "–")
    end
  end

  def locale_switch_path(locale)
    return @locale_switch_paths[locale] if instance_variable_defined?(:@locale_switch_paths)

    url_for(only_path: true, locale: locale)
  end
end
