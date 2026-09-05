require "test_helper"

class Admin::DashboardTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup { sign_in_as_admin }

  test "shows mobile friendly links and content counts" do
    project = Project.new(role: "Engineer")
    project.translations.build(locale: "en", title: "One", slug: "one", summary: "Summary", body_markdown: "Body")
    project.save!

    post = Post.new
    post.translations.build(locale: "en", title: "Two", slug: "two", excerpt: "Excerpt", body_markdown: "Body")
    post.save!

    tag = Tag.new
    tag.translations.build(locale: "en", name: "Ruby", slug: "ruby")
    tag.save!

    get admin_root_path

    assert_response :success
    assert_select "nav[aria-label='Admin']"
    assert_select "a[href='#{admin_projects_path}']", text: /Projects/
    assert_select "a[href='#{admin_posts_path}']", text: /Posts/
    assert_select "a[href='#{admin_tags_path}']", text: /Tags/
    assert_select "a[href='#{edit_admin_profile_path}']", text: /Profile/
    assert_select "a[href='#{edit_admin_resume_path}']", text: /Résumé/
    assert_select "[data-testid='project-count']", text: "1"
    assert_select "[data-testid='post-count']", text: "1"
    assert_select "[data-testid='tag-count']", text: "1"
  end

  test "redirects an unauthenticated request before loading content" do
    sign_out_admin
    get admin_projects_path
    assert_redirected_to new_admin_session_path
  end

  test "shows drafts upcoming schedules and overdue English-blocked work" do
    now = Time.current
    project = Project.create!(
        role: "Developer",
        started_on: Date.new(2026, 1, 1),
        translations_attributes: [
          { locale: "en", title: "Draft English", slug: "draft-english", summary: "Summary", body_markdown: "Body" },
          { locale: "fr", title: "Blocked French", slug: "blocked-french", summary: "Résumé", body_markdown: "Corps" },
          { locale: "vi", title: "Upcoming Vietnamese", slug: "upcoming-vietnamese", summary: "Tóm tắt", body_markdown: "Nội dung" }
        ]
      )
    project.translations.find_by!(locale: "fr").update_columns(state: "scheduled", scheduled_at: now - 1.hour)
    project.translations.find_by!(locale: "vi").update_columns(state: "scheduled", scheduled_at: now + 1.hour)
    published_post = Post.create!(translations_attributes: [
      { locale: "en", title: "Published Post", slug: "published-post", excerpt: "Excerpt", body_markdown: "Body" }
    ])
    travel_to now - 1.day do
      published_post.translations.first.publish
    end

    get admin_root_path

    assert_response :success
    assert_select "#draft-content", text: /Draft English/
    assert_select "#upcoming-publications", text: /Upcoming Vietnamese/
    assert_select "#failed-publications", text: /Blocked French/
    assert_no_match(/Published Post/, response.body)
  end

  test "caps each publishing summary at ten records" do
    11.times do |index|
      Post.create!(translations_attributes: {
        "0" => { locale: "en", title: "Draft #{index}", slug: "draft-#{index}", excerpt: "Excerpt", body_markdown: "Body" }
      })
    end

    get admin_root_path

    assert_select "#draft-content li", count: 10
  end
end
