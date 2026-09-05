require "test_helper"

class ProjectTranslationTest < ActiveSupport::TestCase
  test "reports whether authored content is complete" do
    attributes = { title: "Work", summary: "Summary", body_markdown: "Body" }

    assert ProjectTranslation.new(attributes).complete?
    attributes.each_key do |attribute|
      refute ProjectTranslation.new(attributes.merge(attribute => "")).complete?
    end
  end

  test "generates slug once and does not change it when title changes" do
    project = Project.create!(role: "Engineer", translations_attributes: {
      "0" => { locale: "en", title: "First Title", summary: "Summary", body_markdown: "Body" }
    })
    translation = project.translations.find_by!(locale: "en")
    assert_equal "first-title", translation.slug

    translation.update!(title: "Renamed Title")
    assert_equal "first-title", translation.reload.slug

    translation.update!(slug: "chosen-slug")
    assert_equal "chosen-slug", translation.reload.slug

    translation.slug = "Not/A/Slug"
    assert_not translation.valid?
    assert_includes translation.errors[:slug], "must use lowercase letters, numbers, and single hyphens"
  end
end
