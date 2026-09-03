# frozen_string_literal: true

require "test_helper"

class SearchTextTest < ActiveSupport::TestCase
  test "project search stays published and locale bounded" do
    matching = create_project_translation(slug: "match", summary: "Uses SQLite safely")
    create_project_translation(slug: "draft-match", summary: "Uses SQLite safely", state: "draft")
    french = matching.project.translations.create!(
      locale: "fr", title: "SQLite français", slug: "sqlite-fr",
      summary: "SQLite en français", body_markdown: "Corps", state: "published",
      published_at: 2.days.ago
    )

    results = ProjectTranslation.filtered(locale: "en", query: "SQLite", tag_slug: nil)

    assert_equal [ matching ], results.to_a
    assert_not_includes results, french
  end

  test "literal percent and underscore do not become LIKE wildcards" do
    literal = create_post_translation(slug: "literal", excerpt: "100%_covered")
    create_post_translation(slug: "wildcard", excerpt: "100Xcovered")

    results = PostTranslation.filtered(locale: "en", query: "%_", tag_slug: "")

    assert_equal [ literal ], results.to_a
  end

  test "search case-folds Unicode but keeps accents significant" do
    accented = create_project_translation(slug: "accented", summary: "Système fiable")

    uppercase = ProjectTranslation.filtered(locale: "en", query: "SYSTÈME", tag_slug: nil)
    decomposed = ProjectTranslation.filtered(locale: "en", query: "syste\u0300me", tag_slug: nil)
    unaccented = ProjectTranslation.filtered(locale: "en", query: "systeme", tag_slug: nil)

    assert_equal [ accented ], uppercase.to_a
    assert_equal [ accented ], decomposed.to_a
    assert_empty unaccented
  end

  test "tag slug must be translated in the active locale and attached to the result" do
    tagged = create_project_translation(slug: "tagged", summary: "Tagged work")
    untagged = create_project_translation(slug: "untagged", summary: "Other work")
    tag = Tag.new
    tag.translations.build(locale: "en", name: "Ruby", slug: "ruby")
    tag.translations.build(locale: "fr", name: "Rubis", slug: "rubis")
    tag.save!
    tagged.project.tags << tag

    english = ProjectTranslation.filtered(locale: "en", query: nil, tag_slug: "ruby")
    wrong_locale = ProjectTranslation.filtered(locale: "en", query: nil, tag_slug: "rubis")

    assert_equal [ tagged ], english.to_a
    assert_empty wrong_locale
    assert_not_includes english, untagged
  end

  private

  def create_project_translation(slug:, summary:, state: "published")
    project = Project.new(role: "Engineer")
    project.translations.build(
      locale: "en", title: slug.humanize, slug: slug, summary: summary,
      body_markdown: "Technical body", state: state,
      published_at: (2.days.ago if state == "published")
    )
    project.save!
    project.translations.first
  end

  def create_post_translation(slug:, excerpt:)
    post = Post.new
    post.translations.build(
      locale: "en", title: slug.humanize, slug: slug, excerpt: excerpt,
      body_markdown: "Technical body", state: "published", published_at: 2.days.ago
    )
    post.save!
    post.translations.first
  end
end
