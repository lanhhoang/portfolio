# frozen_string_literal: true

require "test_helper"

class ResponsiveImageHelperTest < ActionView::TestCase
  test "renders truthful width descriptors and intrinsic dimensions" do
    attachment = attached_icon
    attachment.blob.update!(metadata: { "width" => 512, "height" => 512, "analyzed" => true })

    html = responsive_image_tag(
      attachment,
      alt: "Dashboard overview",
      sizes: "(min-width: 48rem) 50vw, 100vw",
      widths: [ 320, 640 ]
    )
    node = Nokogiri::HTML.fragment(html).at_css("img")

    assert_equal "Dashboard overview", node["alt"]
    assert_equal "512", node["width"]
    assert_equal "512", node["height"]
    assert_equal "lazy", node["loading"]
    assert_equal "async", node["decoding"]
    assert_equal "(min-width: 48rem) 50vw, 100vw", node["sizes"]
    assert_includes node["srcset"], "320w"
    assert_includes node["srcset"], "512w"
    assert_not_includes node["srcset"], "640w"
  end

  test "uses the original attachment while analysis metadata is pending" do
    attachment = attached_icon
    attachment.blob.update!(metadata: {})

    html = responsive_image_tag(attachment, alt: "Pending image", sizes: "100vw")
    node = Nokogiri::HTML.fragment(html).at_css("img")

    assert_equal "Pending image", node["alt"]
    assert_nil node["srcset"]
    assert_nil node["width"]
    assert_nil node["height"]
  end

  private

  def attached_icon
    project = Project.new(role: "Engineer")
    project.translations.build(
      locale: "en", title: "Image test", slug: "image-test",
      summary: "Summary", body_markdown: "Body", state: "draft"
    )
    project.save!
    project.cover_image.attach(
      io: Rails.root.join("public/icon.png").open,
      filename: "icon.png",
      content_type: "image/png"
    )
    project.cover_image
  end
end
