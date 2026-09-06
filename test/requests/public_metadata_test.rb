# frozen_string_literal: true

require "test_helper"

class PublicMetadataTest < ActionDispatch::IntegrationTest
  setup do
    host! "portfolio.example"
    https!

    @project = Project.new(role: "Engineer")
    @english = @project.translations.build(
      locale: "en", title: "Fast systems", slug: "fast-systems",
      summary: "A concise case study", body_markdown: "Body",
      state: "published", published_at: Time.zone.parse("2026-08-01 12:00:00")
    )
    @project.save!
    @project.translations.create!(
      locale: "fr", title: "Systèmes rapides", slug: "systemes-rapides",
      summary: "Une étude de cas concise", body_markdown: "Corps",
      state: "published", published_at: Time.zone.parse("2026-08-02 12:00:00")
    )
    @project.translations.create!(
      locale: "vi", title: "Hệ thống nhanh", slug: "he-thong-nhanh",
      summary: "Bản nháp", body_markdown: "Nội dung", state: "draft"
    )
  end

  test "detail metadata is canonical and includes public alternates only" do
    get localized_project_path(locale: :en, slug: @english.slug)

    assert_response :success
    document = Nokogiri::HTML(response.body)
    assert_equal "Fast systems", document.at_css("title").text
    assert_equal "A concise case study", document.at_css('meta[name="description"]')["content"]
    assert_equal "https://portfolio.example/en/projects/fast-systems",
      document.at_css('link[rel="canonical"]')["href"]
    assert_equal({
      "en" => "https://portfolio.example/en/projects/fast-systems",
      "fr" => "https://portfolio.example/fr/projects/systemes-rapides"
    }, document.css('link[rel="alternate"][hreflang]').to_h { |node| [ node["hreflang"], node["href"] ] })
    assert_nil document.at_css('link[hreflang="vi"]')
    assert_nil document.at_css('link[hreflang="x-default"]')
    assert_equal "website", document.at_css('meta[property="og:type"]')["content"]
    assert_equal "en_US", document.at_css('meta[property="og:locale"]')["content"]
    assert_equal "https://portfolio.example/en/projects/fast-systems",
      document.at_css('meta[property="og:url"]')["content"]

    json_node = document.at_css('script[type="application/ld+json"]')
    assert json_node["nonce"].present?
    json_ld = JSON.parse(json_node.text)
    assert_equal "CreativeWork", json_ld.fetch("@type")
    assert_equal "Fast systems", json_ld.fetch("name")
    assert_equal "https://portfolio.example/en/projects/fast-systems", json_ld.fetch("url")
  end

  test "filtered index metadata omits query parameters" do
    get localized_projects_path(locale: :en), params: { q: "rails", tag: "systems" }

    document = Nokogiri::HTML(response.body)
    assert_equal "https://portfolio.example/en/projects",
      document.at_css('link[rel="canonical"]')["href"]
    assert_equal %w[en fr vi], document.css('link[rel="alternate"][hreflang]').map { |node| node["hreflang"] }
    assert document.css('link[rel="alternate"][hreflang]').none? { |node| node["href"].include?("?") }
  end
end
