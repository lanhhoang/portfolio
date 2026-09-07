# frozen_string_literal: true

require "test_helper"

class SitemapTest < ActionDispatch::IntegrationTest
  setup do
    host! "portfolio.example"
    https!

    profile = Profile.new(public_contact_email: "owner@example.test")
    profile.translations.build(
      locale: "en", display_name: "Owner", headline: "Headline",
      introduction: "Introduction", biography_markdown: "Biography",
      availability_label: "Available"
    )
    profile.save!

    project = Project.new(role: "Engineer")
    project.translations.build(
      locale: "en", title: "Visible", slug: "visible", summary: "Summary",
      body_markdown: "Body", state: "published", published_at: 1.day.ago
    )
    project.save!
    project.translations.create!(
      locale: "fr", title: "Brouillon", slug: "brouillon", summary: "Résumé",
      body_markdown: "Corps", state: "draft"
    )
    project.translations.create!(
      locale: "vi", title: "Đã lên lịch", slug: "da-len-lich", summary: "Tóm tắt",
      body_markdown: "Nội dung", state: "scheduled", scheduled_at: 1.day.from_now
    )

    post = Post.new
    post.translations.build(
      locale: "en", title: "Visible post", slug: "visible-post", excerpt: "Excerpt",
      body_markdown: "Body", state: "published", published_at: 1.hour.ago
    )
    post.save!

    future_post = Post.new
    future_post.translations.build(
      locale: "en", title: "Future post", slug: "future-post", excerpt: "Excerpt",
      body_markdown: "Body", state: "published", published_at: 1.day.from_now
    )
    future_post.save!
  end

  test "sitemap contains routable pages and currently public content only" do
    get "/sitemap.xml"

    assert_response :success
    assert_equal "application/xml", response.media_type
    document = Nokogiri::XML(response.body) { |config| config.strict }
    document.remove_namespaces!
    locations = document.xpath("//url/loc").map(&:text)

    assert_includes locations, "https://portfolio.example/en"
    assert_includes locations, "https://portfolio.example/en/projects"
    assert_includes locations, "https://portfolio.example/en/projects/visible"
    assert_includes locations, "https://portfolio.example/en/blog/visible-post"
    assert_includes locations, "https://portfolio.example/en/about"
    assert_not_includes locations, "https://portfolio.example/fr/about"
    assert_not_includes locations, "https://portfolio.example/fr/projects/brouillon"
    assert_not_includes locations, "https://portfolio.example/vi/projects/da-len-lich"
    assert_not_includes locations, "https://portfolio.example/en/blog/future-post"
    assert_equal locations.uniq.sort, locations
    assert locations.all? { |location| location.start_with?("https://portfolio.example/") }
  end
end
