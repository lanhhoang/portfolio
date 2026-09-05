# frozen_string_literal: true

require "test_helper"

class Admin::ProjectTranslations::PublicationsTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @project = Project.create!(role: "Developer", translations_attributes: {
      "0" => { locale: "en", title: "English project", slug: "english-project", summary: "Summary", body_markdown: "Body" },
      "1" => { locale: "fr", title: "Projet français", slug: "projet-francais", summary: "Résumé", body_markdown: "Corps" }
    })
    @english = @project.translations.find_by!(locale: "en")
    @french = @project.translations.find_by!(locale: "fr")
  end

  test "requires a fully authenticated owner" do
    post admin_project_translation_publication_path(@english)
    assert_redirected_to new_admin_session_path
    assert_predicate @english.reload, :draft?
  end

  test "publishes only the selected translation with a 303 redirect" do
    sign_in_as_admin
    post admin_project_translation_publication_path(@english)
    assert_redirected_to edit_admin_project_path(@project), status: :see_other
    assert_predicate @english.reload, :published?
    assert_predicate @french.reload, :draft?
  end

  test "rejects optional publication before English" do
    sign_in_as_admin
    post admin_project_translation_publication_path(@french)
    assert_redirected_to edit_admin_project_path(@project), status: :see_other
    assert_equal "Publish the English translation first", flash[:alert]
    assert_predicate @french.reload, :draft?
  end

  test "schedules the exact ISO instant supplied by the browser" do
    sign_in_as_admin
    instant = 2.hours.from_now.change(sec: 0)
    patch admin_project_translation_publication_path(@english), params: {
      publication: { scheduled_at_local: "2026-09-05T09:30", scheduled_at: instant.iso8601 }
    }
    assert_redirected_to edit_admin_project_path(@project), status: :see_other
    assert_equal instant, @english.reload.scheduled_at
  end

  test "uses explicitly labelled UTC input without JavaScript" do
    sign_in_as_admin
    travel_to Time.zone.local(2026, 9, 5, 8) do
      patch admin_project_translation_publication_path(@english), params: {
        publication: { scheduled_at_local: "2026-09-05T09:30", scheduled_at: "" }
      }
    end

    assert_equal Time.utc(2026, 9, 5, 9, 30), @english.reload.scheduled_at
  end

  test "malformed parameter structure receives the Rails 400 response" do
    sign_in_as_admin
    patch admin_project_translation_publication_path(@english), params: {}
    assert_response :bad_request
    assert_predicate @english.reload, :draft?
  end

  test "rejects malformed and past schedule values without changing state" do
    sign_in_as_admin
    [ { publication: { scheduled_at: "not-a-time" } },
      { publication: { scheduled_at: 1.minute.ago.iso8601 } } ].each do |parameters|
      patch admin_project_translation_publication_path(@english), params: parameters
      assert_response :see_other
      assert_equal "Choose a future publication time", flash[:alert]
      assert_predicate @english.reload, :draft?
    end
  end

  test "unpublishes without changing the slug" do
    sign_in_as_admin
    travel_to 1.minute.ago do
      @english.publish
    end
    delete admin_project_translation_publication_path(@english)
    assert_response :see_other
    assert_predicate @english.reload, :draft?
    assert_equal "english-project", @english.slug
  end

  test "ordinary content updates cannot change publication state" do
    sign_in_as_admin
    patch admin_project_path(@project), params: { project: {
      role: @project.role,
      translations_attributes: {
        "0" => { id: @english.id, title: @english.title, slug: @english.slug,
          summary: @english.summary, body_markdown: @english.body_markdown, state: "published" }
      }
    } }

    assert_response :see_other
    assert_predicate @english.reload, :draft?
  end

  test "edit pages contain standalone publication forms" do
    sign_in_as_admin
    get edit_admin_project_path(@project)
    assert_select "##{ActionView::RecordIdentifier.dom_id(@english, :publication)}"
    assert_select "form form", count: 0
  end
end
