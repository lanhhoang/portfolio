# frozen_string_literal: true

require "application_system_test_case"

class AdminPublishingTest < ApplicationSystemTestCase
  include ActiveSupport::Testing::TimeHelpers
  include ActionView::RecordIdentifier

  test "owner publishes locales independently and a due schedule becomes public" do
    project = Project.create!(
      role: "Developer",
      started_on: Date.new(2026, 1, 1),
      translations_attributes: [
        { locale: "en", title: "English Case Study", slug: "english-case-study", summary: "Summary", body_markdown: "English body" },
        { locale: "fr", title: "Étude de cas", slug: "etude-de-cas", summary: "Résumé", body_markdown: "Corps français" },
        { locale: "vi", title: "Dự án", slug: "du-an", summary: "Tóm tắt", body_markdown: "Nội dung" }
      ]
    )
    english = project.translations.find_by!(locale: "en")
    french = project.translations.find_by!(locale: "fr")
    vietnamese = project.translations.find_by!(locale: "vi")

    sign_in_owner
    page.current_window.resize_to(320, 700)
    visit edit_admin_project_path(project)
    within "##{dom_id(french, :publication)}" do
      assert_button "Publish now", disabled: true
      assert_text "Publish the English translation before publishing this locale."
    end

    within "##{dom_id(english, :publication)}" do
      click_on "Publish now"
    end
    assert_text "English Case Study was published"

    within "##{dom_id(french, :publication)}" do
      click_on "Publish now"
    end
    assert_text "Étude de cas was published"

    visit "/fr/projects/#{french.slug}"
    assert_text "Étude de cas"

    visit edit_admin_project_path(project)
    within "##{dom_id(vietnamese, :publication)}" do
      fill_in "Publication time", with: 1.hour.from_now.change(sec: 0)
      click_on "Schedule"
    end
    assert_text "Dự án was scheduled"

    travel_to vietnamese.reload.scheduled_at + 1.minute do
      PublishDueTranslationsJob.perform_now
      visit "/vi/projects/#{vietnamese.slug}"
    end
    assert_text "Dự án"
    assert_text "Nội dung"
  end
end
