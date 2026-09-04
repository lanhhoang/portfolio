require "test_helper"

class TagTranslationTest < ActiveSupport::TestCase
  test "reports whether authored content is complete" do
    assert TagTranslation.new(name: "Rails").complete?
    refute TagTranslation.new(name: "").complete?
  end

  test "generates slug once and does not change it when name changes" do
    tag = Tag.create!(translations_attributes: {
      "0" => { locale: "en", name: "Ruby on Rails" }
    })
    translation = tag.translations.find_by!(locale: "en")
    assert_equal "ruby-on-rails", translation.slug

    translation.update!(name: "Rails")
    assert_equal "ruby-on-rails", translation.reload.slug

    translation.update!(slug: "rails-framework")
    assert_equal "rails-framework", translation.reload.slug

    translation.slug = "rails--framework"
    assert_not translation.valid?
    assert_includes translation.errors[:slug], "must use lowercase letters, numbers, and single hyphens"
  end
end
