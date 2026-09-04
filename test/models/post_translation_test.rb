require "test_helper"

class PostTranslationTest < ActiveSupport::TestCase
  test "reports whether authored content is complete" do
    attributes = { title: "Post", excerpt: "Excerpt", body_markdown: "Body" }

    assert PostTranslation.new(attributes).complete?
    attributes.each_key do |attribute|
      refute PostTranslation.new(attributes.merge(attribute => "")).complete?
    end
  end

  test "generates slug once and does not change it when title changes" do
    post = Post.create!(translations_attributes: {
      "0" => { locale: "en", title: "First Post", excerpt: "Excerpt", body_markdown: "Body" }
    })
    translation = post.translations.find_by!(locale: "en")
    assert_equal "first-post", translation.slug

    translation.update!(title: "Renamed Post")
    assert_equal "first-post", translation.reload.slug

    translation.update!(slug: "chosen-post")
    assert_equal "chosen-post", translation.reload.slug

    translation.slug = "two words"
    assert_not translation.valid?
    assert_includes translation.errors[:slug], "must use lowercase letters, numbers, and single hyphens"
  end
end
