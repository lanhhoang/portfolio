# frozen_string_literal: true

module MetadataHelper
  OG_LOCALES = { "en" => "en_US", "fr" => "fr_FR", "vi" => "vi_VN" }.freeze

  def page_metadata(title:, description:, canonical_url: current_page_canonical_url,
                    alternates: alternate_locale_links, og_type: "website",
                    image_url: nil, json_ld: nil, robots: "index,follow")
    title = title.to_s.strip
    description = strip_tags(description.to_s).squish.truncate(160)
    content_for :title, title

    tags = [
      tag.meta(name: "description", content: description),
      tag.meta(name: "robots", content: robots),
      tag.link(rel: "canonical", href: canonical_url),
      tag.meta(property: "og:site_name", content: t("seo.site_name")),
      tag.meta(property: "og:title", content: title),
      tag.meta(property: "og:description", content: description),
      tag.meta(property: "og:type", content: og_type),
      tag.meta(property: "og:url", content: canonical_url),
      tag.meta(property: "og:locale", content: OG_LOCALES.fetch(I18n.locale.to_s))
    ]
    alternates.each do |alternate|
      tags << tag.link(rel: "alternate", hreflang: alternate.fetch(:locale), href: alternate.fetch(:url))
      if alternate.fetch(:locale) != I18n.locale.to_s
        tags << tag.meta(property: "og:locale:alternate", content: OG_LOCALES.fetch(alternate.fetch(:locale)))
      end
    end
    if image_url.present?
      tags << tag.meta(property: "og:image", content: image_url)
    end
    if json_ld.present?
      tags << tag.script(
        raw(json_escape(json_ld.to_json)),
        type: "application/ld+json",
        nonce: content_security_policy_nonce
      )
    end

    content_for :head, safe_join(tags, "\n")
  end

  def current_page_canonical_url(overrides = {})
    url_for(request.path_parameters.merge(overrides).merge(only_path: false))
  end

  def alternate_locale_links(locale_switch_paths: nil)
    PublicController::SUPPORTED_LOCALES.filter_map do |locale|
      path = if locale_switch_paths
        locale_switch_paths[locale]
      else
        url_for(request.path_parameters.merge(locale: locale, only_path: true))
      end
      if path
        { locale: locale, url: "#{request.base_url}#{path}" }
      end
    end
  end

  def project_json_ld(translation)
    {
      "@context" => "https://schema.org",
      "@type" => "CreativeWork",
      "name" => translation.title,
      "description" => strip_tags(translation.summary.to_s).squish,
      "inLanguage" => translation.locale,
      "datePublished" => translation.published_at&.iso8601,
      "url" => current_page_canonical_url
    }.compact
  end

  def post_json_ld(translation)
    {
      "@context" => "https://schema.org",
      "@type" => "BlogPosting",
      "headline" => translation.title,
      "description" => strip_tags(translation.excerpt.to_s).squish,
      "inLanguage" => translation.locale,
      "datePublished" => translation.published_at&.iso8601,
      "url" => current_page_canonical_url
    }.compact
  end

  def person_json_ld(translation)
    {
      "@context" => "https://schema.org",
      "@type" => "Person",
      "name" => translation.display_name,
      "description" => strip_tags(translation.introduction.to_s).squish,
      "url" => current_page_canonical_url
    }
  end
end
