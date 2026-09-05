# frozen_string_literal: true

require "test_helper"

class PublishDueTranslationsJobTest < ActiveJob::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "publishes due English project and post translations but not future work" do
    now = Time.zone.local(2026, 9, 2, 12, 0, 0)
    project_due = create_project("due-project").translations.find_by!(locale: "en")
    post_due = create_post("due-post").translations.find_by!(locale: "en")
    future = create_post("future-post").translations.find_by!(locale: "en")
    project_due.update_columns(state: "scheduled", scheduled_at: now - 2.hours)
    post_due.update_columns(state: "scheduled", scheduled_at: now)
    future.update_columns(state: "scheduled", scheduled_at: now + 1.minute)

    travel_to now do
      PublishDueTranslationsJob.perform_now
    end

    assert_equal now, project_due.reload.published_at
    assert_equal now, post_due.reload.published_at
    assert_predicate future.reload, :scheduled?
  end

  test "publishes overdue work on the first scan after downtime" do
    now = Time.zone.local(2026, 9, 2, 12, 0, 0)
    translation = create_project("catch-up").translations.find_by!(locale: "en")
    translation.update_columns(state: "scheduled", scheduled_at: now - 3.days)

    travel_to now do
      PublishDueTranslationsJob.perform_now
    end

    assert_predicate translation.reload, :published?
    assert_equal now, translation.published_at
  end

  test "publishes due English before a due optional locale in the same scan" do
    now = Time.zone.local(2026, 9, 2, 12, 0, 0)
    project = create_project("ordered", optional_locales: [ "fr" ])
    project.translations.update_all(state: "scheduled", scheduled_at: now - 1.minute)

    travel_to now do
      PublishDueTranslationsJob.perform_now
    end

    assert_predicate project.translations.find_by!(locale: "en"), :published?
    assert_predicate project.translations.find_by!(locale: "fr"), :published?
  end

  test "leaves blocked optional work scheduled and catches it up later" do
    now = Time.zone.local(2026, 9, 2, 12, 0, 0)
    project = create_project("blocked", optional_locales: [ "fr" ])
    english = project.translations.find_by!(locale: "en")
    french = project.translations.find_by!(locale: "fr")
    french.update_columns(state: "scheduled", scheduled_at: now - 1.hour)

    travel_to now do
      PublishDueTranslationsJob.perform_now
    end
    assert_predicate french.reload, :scheduled?

    travel_to now + 1.minute do
      english.publish
    end
    travel_to now + 2.minutes do
      PublishDueTranslationsJob.perform_now
    end

    assert_predicate french.reload, :published?
    assert_equal now + 2.minutes, french.published_at
  end

  test "a repeated scan preserves the first publication timestamp" do
    first_scan = Time.zone.local(2026, 9, 2, 12, 0, 0)
    translation = create_post("idempotent").translations.find_by!(locale: "en")
    translation.update_columns(state: "scheduled", scheduled_at: first_scan - 1.minute)

    travel_to first_scan do
      PublishDueTranslationsJob.perform_now
    end
    travel_to first_scan + 1.minute do
      PublishDueTranslationsJob.perform_now
    end

    assert_equal first_scan, translation.reload.published_at
  end

  test "does not publish a stale candidate that was returned to draft" do
    now = Time.zone.local(2026, 9, 2, 12)
    translation = create_post("cancelled").translations.find_by!(locale: "en")
    translation.update_columns(state: "scheduled", scheduled_at: now - 1.minute)
    stale_candidate = PostTranslation.find(translation.id)
    translation.update_columns(state: "draft", scheduled_at: nil)
    stale_scope = Object.new
    stale_scope.define_singleton_method(:find_each) { |&block| block.call(stale_candidate) }

    travel_to now do
      PublishDueTranslationsJob.new.send(:publish_scope, stale_scope, at: now)
    end

    assert_predicate translation.reload, :draft?
  end

  private

  def create_project(slug, optional_locales: [])
    Project.create!(
      role: "Developer",
      started_on: Date.new(2026, 1, 1),
      translations_attributes: ([ "en" ] + optional_locales).map do |locale|
        { locale: locale, title: "#{slug} #{locale}", slug: "#{slug}-#{locale}", summary: "Summary", body_markdown: "Body" }
      end
    )
  end

  def create_post(slug)
    Post.create!(translations_attributes: [
      { locale: "en", title: slug, slug: slug, excerpt: "Excerpt", body_markdown: "Body" }
    ])
  end
end
