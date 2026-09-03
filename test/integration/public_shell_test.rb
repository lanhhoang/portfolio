require "test_helper"

class PublicShellTest < ActionDispatch::IntegrationTest
  test "layout exposes semantic locale accent navigation and controls" do
    get localized_root_path(locale: "en")

    assert_response :success
    assert_select "html[lang='en'][data-accent='lime']"
    assert_select "a.skip-link[href='#main-content']", text: "Skip to content"
    assert_select "header.site-header"
    assert_select "nav#primary-navigation[aria-label='Primary navigation']"
    assert_select "button[aria-controls='primary-navigation'][aria-expanded='false']"
    assert_select "nav.locale-switcher[aria-label='Choose language'] a", count: 3
    assert_select "button[data-controller='theme'][data-theme-target='toggle']"
    assert_select "footer.site-footer"
  end

  test "saved-theme bootstrap appears before the stylesheet" do
    get localized_root_path(locale: "en")

    script_position = response.body.index('localStorage.getItem("portfolio-theme")')
    stylesheet_position = response.body.index('rel="stylesheet"')

    assert script_position, "Expected inline theme bootstrap"
    assert stylesheet_position, "Expected stylesheet link"
    assert_operator script_position, :<, stylesheet_position
  end

  test "French shell uses translated accessible labels" do
    get localized_projects_path(locale: "fr")

    assert_select "html[lang='fr']"
    assert_select "nav[aria-label='Navigation principale']"
    assert_select "a[aria-current='page']", text: "Réalisations"
    assert_select "a[href='#{localized_projects_path(locale: "vi")}']", text: "Tiếng Việt"
  end

  test "Vietnamese shell translates both theme actions" do
    get localized_root_path(locale: "vi")

    assert_select "button[data-theme-light-label-value='Chuyển sang giao diện sáng'][data-theme-dark-label-value='Chuyển sang giao diện tối']"
  end
end
