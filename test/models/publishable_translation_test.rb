# frozen_string_literal: true

require "test_helper"

class PublishableTranslationTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "publishing English records the current time and clears its schedule" do
    translation = create_project.translations.find_by!(locale: "en")
    translation.update_columns(state: "scheduled", scheduled_at: 1.hour.ago)
    publication_time = Time.zone.local(2026, 9, 2, 12, 0, 0)

    travel_to publication_time do
      assert_same translation, translation.publish
    end

    translation.reload
    assert_predicate translation, :published?
    assert_equal publication_time, translation.published_at
    assert_nil translation.scheduled_at
  end

  test "non-English publication requires a published English sibling" do
    project = create_project(optional_locales: [ "fr" ])
    french = project.translations.find_by!(locale: "fr")

    error = assert_raises(PublishableTranslation::EnglishMustBePublished) do
      french.publish
    end

    assert_equal "Publish the English translation first", error.message
    assert_predicate french.reload, :draft?
    assert_nil french.published_at
  end

  test "non-English publication succeeds after English publication" do
    project = create_project(optional_locales: [ "fr" ])
    english = project.translations.find_by!(locale: "en")
    french = project.translations.find_by!(locale: "fr")

    travel_to 2.minutes.ago do
      english.publish
    end
    travel_to 1.minute.ago do
      french.publish
    end

    assert_predicate french.reload, :published?
  end

  test "normal validation cannot bypass English-first publication" do
    project = create_project(optional_locales: [ "fr" ])
    french = project.translations.find_by!(locale: "fr")
    french.assign_attributes(state: :published, published_at: Time.current)

    assert_not french.valid?
    assert_includes french.errors[:state], "requires the English translation to be published first"
  end

  test "unpublishing English does not cascade to an independently published locale" do
    project = create_project(optional_locales: [ "fr" ])
    english = project.translations.find_by!(locale: "en")
    french = project.translations.find_by!(locale: "fr")
    english.publish
    french.publish

    english.unpublish

    assert_predicate english.reload, :draft?
    assert_predicate french.reload, :published?
  end

  test "scheduling uses a future time and clears an old publication time" do
    translation = create_post.translations.find_by!(locale: "en")
    travel_to 1.day.ago do
      translation.publish
    end
    scheduled_time = 2.hours.from_now.change(usec: 0)

    assert_same translation, translation.schedule(at: scheduled_time)

    translation.reload
    assert_predicate translation, :scheduled?
    assert_equal scheduled_time, translation.scheduled_at
    assert_nil translation.published_at
  end

  test "scheduling rejects blank or non-future times without changing the row" do
    translation = create_post.translations.find_by!(locale: "en")

    [ nil, 1.minute.ago ].each do |invalid_time|
      assert_raises(PublishableTranslation::InvalidScheduleTime) do
        translation.schedule(at: invalid_time)
      end
    end

    assert_predicate translation.reload, :draft?
    assert_nil translation.scheduled_at
  end

  test "unpublishing returns to draft and preserves the localized slug" do
    translation = create_project.translations.find_by!(locale: "en")
    original_slug = translation.slug
    travel_to 1.minute.ago do
      translation.publish
    end

    assert_same translation, translation.unpublish

    translation.reload
    assert_predicate translation, :draft?
    assert_equal original_slug, translation.slug
    assert_nil translation.scheduled_at
    assert_nil translation.published_at
  end

  test "publishing an already-published translation performs no second write" do
    translation = create_project.translations.find_by!(locale: "en")
    first_time = Time.zone.local(2026, 9, 2, 12, 0, 0)
    travel_to first_time do
      translation.publish
    end
    first_updated_at = translation.reload.updated_at

    travel 1.hour do
      assert_no_changes -> { translation.reload.attributes.slice("published_at", "updated_at") } do
        translation.publish
      end
    end

    assert_equal first_time, translation.published_at
    assert_equal first_updated_at, translation.updated_at
  end

  test "due and upcoming scopes partition scheduled rows at the cutoff" do
    post = create_post(optional_locales: [ "fr" ])
    now = Time.zone.local(2026, 9, 2, 12, 0, 0)
    due = post.translations.find_by!(locale: "en")
    upcoming = post.translations.find_by!(locale: "fr")
    due.update_columns(state: "scheduled", scheduled_at: now)
    upcoming.update_columns(state: "scheduled", scheduled_at: now + 1.minute)

    assert_equal [ due ], PostTranslation.due(now).to_a
    assert_equal [ upcoming ], PostTranslation.upcoming(now).to_a
  end

  test "project and post translations expose their publication parent" do
    project = create_project
    post = create_post

    assert_equal project, project.translations.first.publication_parent
    assert_equal post, post.translations.first.publication_parent
  end

  private

  def create_project(optional_locales: [])
    Project.create!(
      role: "Developer",
      started_on: Date.new(2026, 1, 1),
      translations_attributes: translation_attributes("Project", optional_locales, summary: "Summary")
    )
  end

  def create_post(optional_locales: [])
    Post.create!(
      translations_attributes: translation_attributes("Post", optional_locales, excerpt: "Excerpt")
    )
  end

  def translation_attributes(prefix, optional_locales, summary: nil, excerpt: nil)
    ([ "en" ] + optional_locales).map do |locale|
      {
        locale: locale,
        title: "#{prefix} #{locale}",
        slug: "#{prefix.downcase}-#{locale}",
        summary: summary,
        excerpt: excerpt,
        body_markdown: "# #{prefix} #{locale}"
      }.compact
    end
  end
end
