# frozen_string_literal: true

require "test_helper"

class PublicContentTest < ActiveSupport::TestCase
  test "every shared localized record requires an English translation" do
    records = [
      Project.new(role: "Designer"),
      Post.new,
      Tag.new,
      Profile.new(public_contact_email: "owner@example.test"),
      Resume.new(updated_on: Date.new(2026, 9, 2))
    ]

    records.each do |record|
      assert_not record.valid?
      assert_includes record.errors[:translations], "must include English"
    end
  end

  test "French and Vietnamese translations remain optional" do
    project = Project.new(role: "Designer")
    project.translations.build(
      locale: "en", title: "Demo", slug: "demo", summary: "Summary",
      body_markdown: "Body", state: "draft"
    )

    assert project.save
    assert_equal [ "en" ], project.translations.pluck(:locale)
  end

  test "translation locale and slug pairs are unique" do
    first = build_project(slug: "shared-slug")
    assert first.save!

    second = build_project(slug: "shared-slug")
    assert_not second.save
    assert_includes second.translations.first.errors[:slug], "has already been taken"

    first.translations.create!(
      locale: "fr", title: "Démo", slug: "shared-slug", summary: "Résumé",
      body_markdown: "Corps", state: "draft"
    )
    assert_equal 2, first.translations.count
  end

  test "public scopes require the requested locale and a published timestamp not in the future" do
    visible = build_project(slug: "visible", state: "published", published_at: 1.day.ago)
    draft = build_project(slug: "draft", state: "draft")
    future = build_project(slug: "future", state: "published", published_at: 1.day.from_now)
    [ visible, draft, future ].each(&:save!)
    visible.translations.create!(
      locale: "fr", title: "Visible", slug: "visible-fr", summary: "Résumé",
      body_markdown: "Corps", state: "published", published_at: 1.day.ago
    )

    assert_equal [ "visible" ], ProjectTranslation.publicly_visible(locale: "en").pluck(:slug)
    assert_equal [ "visible-fr" ], ProjectTranslation.publicly_visible(locale: "fr").pluck(:slug)
  end

  test "profile and resume singleton rows are database constrained and exposed through current" do
    profile = Profile.new(public_contact_email: "owner@example.test")
    profile.translations.build(
      locale: "en", display_name: "Demo Owner", headline: "Ideas. Interfaces. Impact.",
      introduction: "A demonstration profile.", biography_markdown: "Biography",
      availability_label: "Available"
    )
    profile.save!

    resume = Resume.new(updated_on: Date.new(2026, 9, 2))
    resume.translations.build(
      locale: "en", title: "Résumé", description: "Demonstration résumé"
    )
    resume.save!

    assert_equal profile, Profile.current
    assert_equal resume, Resume.current
    assert_raises(ActiveRecord::RecordNotUnique) do
      Profile.insert!({ public_contact_email: "second@example.test", singleton_guard: 1 })
    end
  end

  test "attachment names are stable and reject MIME extension and size independently" do
    assert_equal %w[cover_image gallery_images], Project.attachment_reflections.keys.sort
    assert_equal %w[cover_image], Post.attachment_reflections.keys
    assert_equal %w[portrait], Profile.attachment_reflections.keys
    assert_equal %w[pdf], ResumeTranslation.attachment_reflections.keys

    project = build_project(slug: "invalid-image")
    project.cover_image.attach(
      io: StringIO.new("plain text"), filename: "cover.png", content_type: "text/plain"
    )
    assert_not project.valid?
    assert_includes project.errors[:cover_image], "must be a JPEG, PNG, or WebP image"

    wrong_extension = build_project(slug: "wrong-extension")
    wrong_extension.cover_image.attach(
      io: StringIO.new("image bytes"), filename: "cover.txt", content_type: "image/png"
    )
    assert_not wrong_extension.valid?
    assert_includes wrong_extension.errors[:cover_image], "must be a JPEG, PNG, or WebP image"

    resume = Resume.new(updated_on: Date.new(2026, 9, 2))
    translation = resume.translations.build(locale: "en", title: "Résumé", description: "English")
    oversized = ActiveStorage::Blob.create_before_direct_upload!(
      filename: "resume.pdf", byte_size: 5.megabytes + 1,
      checksum: Digest::MD5.base64digest(""), content_type: "application/pdf",
      metadata: { identified: true }
    )
    translation.pdf.attach(oversized)
    assert_not resume.valid?
    assert_includes translation.errors[:pdf], "must be 5 MB or smaller"
  end

  test "public email and external links require valid public URL forms" do
    profile = Profile.new(
      public_contact_email: "not-an-email",
      social_links: { "GitHub" => "javascript:alert(1)" }
    )
    profile.translations.build(
      locale: "en", display_name: "Demo", headline: "Headline",
      introduction: "Introduction", biography_markdown: "Biography",
      availability_label: "Available"
    )
    project = build_project(slug: "invalid-links")
    project.live_url = "ftp://example.test/project"
    project.source_url = "https:///missing-host"

    assert_not profile.valid?
    assert profile.errors[:public_contact_email].any?
    assert profile.errors[:social_links].any?
    assert_not project.valid?
    assert project.errors[:live_url].any?
    assert project.errors[:source_url].any?
  end

  test "Markdown HTML is refreshed before translated content is saved" do
    project = build_project(slug: "rendered")
    project.translations.first.body_markdown = "**Safe** <script>alert(1)</script>"
    project.save!

    translation = project.translations.first.reload
    assert_includes translation.body_html, "<strong>Safe</strong>"
    assert_not_includes translation.body_html, "<script"
  end

  private

  def build_project(slug:, state: "draft", published_at: nil)
    Project.new(role: "Designer").tap do |project|
      project.translations.build(
        locale: "en", title: slug.humanize, slug: slug, summary: "Summary",
        body_markdown: "Body", state: state, published_at: published_at
      )
    end
  end
end
