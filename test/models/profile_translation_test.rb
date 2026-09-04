require "test_helper"

class ProfileTranslationTest < ActiveSupport::TestCase
  test "reports whether authored content is complete" do
    attributes = {
      display_name: "Owner", headline: "Headline", introduction: "Introduction",
      biography_markdown: "Biography", availability_label: "Available"
    }

    assert ProfileTranslation.new(attributes).complete?
    attributes.each_key do |attribute|
      refute ProfileTranslation.new(attributes.merge(attribute => "")).complete?
    end
  end
end
