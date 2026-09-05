require "test_helper"

class Admin::DashboardTest < ActionDispatch::IntegrationTest
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
end
