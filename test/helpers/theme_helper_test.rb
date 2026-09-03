require "test_helper"

class ThemeHelperTest < ActionView::TestCase
  def content_security_policy_nonce = "test-nonce"

  test "accepts exactly the five accent presets" do
    assert_equal %w[brown green lime orange yellow], ThemeHelper::ACCENT_PRESETS

    ThemeHelper::ACCENT_PRESETS.each do |preset|
      assert_equal preset, accent_preset(preset)
    end
  end

  test "defaults missing or invalid accents to lime" do
    assert_equal "lime", accent_preset(nil)
    assert_equal "lime", accent_preset("purple")
  end

  test "bootstrap reads only a valid saved light or dark override" do
    script = theme_bootstrap_script

    assert_includes script, 'localStorage.getItem("portfolio-theme")'
    assert_includes script, 'theme === "light" || theme === "dark"'
    assert_includes script, "document.documentElement.dataset.theme = theme"
  end
end
