require "test_helper"

class FontAssetsTest < ActiveSupport::TestCase
  test "self-hosts and applies Be Vietnam Pro" do
    normal_font = Rails.root.join("public/fonts/BeVietnamPro-Variable.ttf")
    italic_font = Rails.root.join("public/fonts/BeVietnamPro-Italic-Variable.ttf")
    license = Rails.root.join("vendor/fonts/be-vietnam-pro/OFL.txt")
    stylesheet = Rails.root.join("app/assets/tailwind/application.css").read

    assert File.exist?(normal_font), "missing #{normal_font}"
    assert File.exist?(italic_font), "missing #{italic_font}"
    assert File.exist?(license), "missing #{license}"
    assert_includes stylesheet, 'font-family: "Be Vietnam Pro"'
    assert_includes stylesheet, 'url("/fonts/BeVietnamPro-Variable.ttf")'
    assert_includes stylesheet, 'url("/fonts/BeVietnamPro-Italic-Variable.ttf")'
    assert_includes stylesheet, '--font-body: "Be Vietnam Pro"'
    assert_includes stylesheet, '--font-display: "Be Vietnam Pro"'
  end
end
