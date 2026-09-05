require "test_helper"

class Admin::ContentHelperTest < ActionView::TestCase
  include Admin::ContentHelper

  test "presents a translation state when the model has one" do
    assert_equal "Draft", translation_state_label(PostTranslation.new(state: "draft"))
    assert_nil translation_state_label(TagTranslation.new)
  end

  test "uses a deterministic locale specific preview frame id" do
    translation = ProjectTranslation.new(locale: "vi")
    assert_equal "project_vi_markdown_preview", markdown_preview_frame_id(translation)
  end
end
