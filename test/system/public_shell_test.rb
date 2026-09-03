require "application_system_test_case"

class PublicShellTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 320, 800 ]

  test "locale choice survives navigation and a root reload" do
    visit localized_root_path(locale: "en")

    within ".locale-switcher" do
      click_link "Français"
    end
    assert_current_path localized_root_path(locale: "fr")

    find(".site-mark").click
    assert_current_path localized_root_path(locale: "fr")

    visit root_path
    assert_current_path localized_root_path(locale: "fr")
  end

  test "site mark has a comfortable touch target" do
    visit localized_root_path(locale: "en")

    assert_operator page.evaluate_script("document.querySelector('.site-mark').getBoundingClientRect().width"), :>=, 44
  end

  test "mobile menu is keyboard operable and the page does not overflow" do
    page.current_window.resize_to(320, 800)
    visit localized_root_path(locale: "en")

    assert_selector "#primary-navigation", visible: :hidden
    menu_button = find("button[aria-controls='primary-navigation']")
    menu_button.click

    assert_selector "#primary-navigation", visible: :visible
    assert_equal "true", menu_button["aria-expanded"]

    find("body").send_keys(:escape)
    assert_selector "#primary-navigation", visible: :hidden
    assert_equal "false", menu_button["aria-expanded"]
    assert page.active_element.matches_selector?(".menu-button")
    assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")

    page.current_window.resize_to(1280, 900)
    visit localized_root_path(locale: "en")
    assert_selector "#primary-navigation", visible: :visible
    assert_selector ".menu-button", visible: :hidden
  end

  test "public search controls remain visible and usable at mobile width" do
    page.current_window.resize_to(320, 800)
    visit localized_projects_path(locale: "en")

    metrics = page.evaluate_script(<<~JAVASCRIPT)
      Array.from(document.querySelectorAll('form[role="search"] input, form[role="search"] select')).map((control) => {
        const style = getComputedStyle(control);
        return {
          height: control.getBoundingClientRect().height,
          borderWidth: parseFloat(style.borderTopWidth),
          paddingLeft: parseFloat(style.paddingLeft)
        };
      });
    JAVASCRIPT

    assert_equal 3, metrics.size
    assert metrics.all? { |item| item["height"] >= 44 }
    assert metrics.all? { |item| item["borderWidth"] >= 1 }
    assert metrics.all? { |item| item["paddingLeft"] >= 8 }
    assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")
  end

  test "theme override is accessible and persists across pages" do
    visit localized_root_path(locale: "en")
    page.execute_script('localStorage.removeItem("portfolio-theme")')
    visit localized_projects_path(locale: "en")
    page.execute_script('localStorage.removeItem("portfolio-theme")')
    visit localized_projects_path(locale: "en")

    assert_selector "[data-theme-target='toggle'][aria-pressed]"
    toggle = find("[data-theme-target='toggle']")
    assert_includes %w[true false], toggle["aria-pressed"]
    toggle.click

    selected_theme = page.evaluate_script('localStorage.getItem("portfolio-theme")')
    assert_includes %w[light dark], selected_theme
    assert_equal selected_theme, page.evaluate_script("document.documentElement.dataset.theme")

    visit localized_projects_path(locale: "en")
    assert_equal selected_theme, page.evaluate_script("document.documentElement.dataset.theme")
    assert_equal((selected_theme == "dark").to_s, find("[data-theme-target='toggle']")["aria-pressed"])
  end
end
