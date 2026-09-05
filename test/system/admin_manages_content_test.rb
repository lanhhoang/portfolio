require "application_system_test_case"

class AdminManagesContentTest < ApplicationSystemTestCase
  setup do
    Profile.create!(
      public_contact_email: "owner@example.test",
      translations_attributes: {
        "0" => {
          locale: "en", display_name: "Portfolio Owner", headline: "Ideas. Interfaces. Impact.",
          introduction: "Short introduction", biography_markdown: "Biography", availability_label: "Available"
        }
      }
    )
    Resume.create!(
      updated_on: Date.new(2026, 9, 2),
      translations_attributes: {
        "0" => { locale: "en", title: "Résumé", description: "Current résumé" }
      }
    )
    sign_in_owner
    page.current_window.resize_to(320, 700)
  end

  test "owner creates translations, previews markdown, uploads assets, and changes accent" do
    visit new_admin_project_path
    fill_in "Role", with: "Lead developer"
    fill_in "Title", with: "Phone-first project", match: :first
    fill_in "Summary", with: "Created from a narrow viewport", match: :first
    fill_in "Body (Markdown)", with: "# Preview heading", match: :first
    attach_file "Cover image", Rails.root.join("public/icon.png")
    click_button "Preview", match: :first
    within("turbo-frame#project_en_markdown_preview") { assert_text "Preview heading" }
    fill_in "Body (Markdown)", with: "# Updated preview", match: :first
    click_button "Preview", match: :first
    within("turbo-frame#project_en_markdown_preview") { assert_text "Updated preview" }

    click_button "French"
    within("[role='tabpanel']:not([hidden])") do
      fill_in "Title", with: "Projet mobile"
      fill_in "Summary", with: "Résumé français"
      fill_in "Body (Markdown)", with: "# Aperçu"
    end
    click_button "Create project"
    assert_text "Project created."

    project = Project.order(:id).last
    assert_equal "phone-first-project", project.translations.find_by!(locale: "en").slug
    assert_equal %w[en fr], project.translations.order(:locale).pluck(:locale)
    assert project.cover_image.attached?

    visit edit_admin_profile_path
    choose "Orange"
    click_button "Save profile"
    assert_checked_field "Orange"

    visit edit_admin_resume_path
    fill_in "Updated on", with: "2026-09-02"
    attach_file "PDF", file_fixture("resume.pdf"), match: :first
    click_button "Save résumé"
    assert_text "resume.pdf"

    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
      page.evaluate_script("document.documentElement.clientWidth")
  end

  test "locale tabs support keyboard navigation" do
    visit new_admin_post_path
    english = find("[role='tab']", text: "English")
    english.send_keys(:arrow_right)
    assert_equal "true", find("[role='tab']", text: "French")["aria-selected"]
    assert_selector "[role='tabpanel']:not([hidden])"
    find("[role='tab']", text: "French").send_keys(:end)
    assert_equal "true", find("[role='tab']", text: "Vietnamese")["aria-selected"]
    find("[role='tab']", text: "Vietnamese").send_keys(:home)
    assert_equal "true", find("[role='tab']", text: "English")["aria-selected"]
  end

  test "preview request failures are visible without losing editor content" do
    visit new_admin_post_path
    fill_in "Body (Markdown)", with: "Unsaved body", match: :first
    editor = find("[data-controller~='markdown-preview']", match: :first)
    page.execute_script(
      'arguments[0].setAttribute("data-markdown-preview-url-value", "/missing-preview")',
      editor
    )

    click_button "Preview", match: :first

    within("turbo-frame#post_en_markdown_preview") do
      assert_text "Preview unavailable. Try again."
    end
    assert_field "Body (Markdown)", with: "Unsaved body", match: :first
  end
end
