# frozen_string_literal: true

class SitemapController < ApplicationController
  def show
    @urls = PublicController::SUPPORTED_LOCALES.flat_map do |locale|
      static_urls(locale) + singleton_urls(locale) + content_urls(locale)
    end.uniq.sort
  end

  private

  def static_urls(locale)
    [
      localized_root_url(locale: locale),
      localized_projects_url(locale: locale),
      localized_blog_url(locale: locale),
      localized_contact_url(locale: locale)
    ]
  end

  def singleton_urls(locale)
    urls = []
    if ProfileTranslation.exists?(locale: locale)
      urls << localized_about_url(locale: locale)
    end
    if ResumeTranslation.exists?(locale: locale)
      urls << localized_resume_url(locale: locale)
    end
    urls
  end

  def content_urls(locale)
    projects = ProjectTranslation.publicly_visible(locale: locale).pluck(:slug).map do |slug|
      localized_project_url(locale: locale, slug: slug)
    end
    posts = PostTranslation.publicly_visible(locale: locale).pluck(:slug).map do |slug|
      localized_post_url(locale: locale, slug: slug)
    end
    projects + posts
  end
end
