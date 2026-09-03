require "test_helper"

class PublicLocalizationTest < ActionDispatch::IntegrationTest
  setup do
    profile = Profile.new(public_contact_email: "owner@example.test")
    {
      "en" => [ "Demo Owner", "About" ],
      "fr" => [ "Propriétaire démo", "À propos" ],
      "vi" => [ "Chủ sở hữu mẫu", "Giới thiệu" ]
    }.each do |locale, (display_name, headline)|
      profile.translations.build(
        locale: locale, display_name: display_name, headline: headline,
        introduction: "A demonstration profile.", biography_markdown: "Biography",
        availability_label: "Available"
      )
    end
    profile.save!

    resume = Resume.new(updated_on: Date.new(2026, 9, 2))
    %w[en fr vi].each do |locale|
      resume.translations.build(locale: locale, title: "Résumé", description: "Demonstration résumé")
    end
    resume.save!
  end
  test "root falls back to English" do
    get root_path

    assert_redirected_to localized_root_path(locale: "en")
  end

  test "root chooses the supported language with the highest quality" do
    get root_path, headers: { "Accept-Language" => "de-DE, vi;q=0.8, fr-FR;q=0.9, en;q=0.7" }

    assert_redirected_to localized_root_path(locale: "fr")
  end

  test "root ignores invalid quality values" do
    get root_path, headers: { "Accept-Language" => "vi;q=9, fr;q=0.8" }

    assert_redirected_to localized_root_path(locale: "fr")
  end

  test "saved locale wins over Accept-Language" do
    get localized_about_path(locale: "vi")
    assert_response :success
    assert_equal "vi", cookies[:portfolio_locale]

    get root_path, headers: { "Accept-Language" => "fr" }

    assert_redirected_to localized_root_path(locale: "vi")
  end

  test "unsupported saved locale is ignored" do
    cookies[:portfolio_locale] = "de"

    get root_path, headers: { "Accept-Language" => "fr" }

    assert_redirected_to localized_root_path(locale: "fr")
  end

  test "every shell page renders in each explicit locale" do
    routes = %i[
      localized_root_path
      localized_projects_path
      localized_blog_path
      localized_about_path
      localized_resume_path
      localized_contact_path
    ]

    %w[en fr vi].product(routes).each do |locale, route|
      get public_send(route, locale: locale)
      assert_response :success, "Expected #{route} to render for #{locale}"
      assert_equal locale, cookies[:portfolio_locale]
    end
  end

  test "fixed copy comes from the active locale without fallback" do
    {
      "en" => "Demo Owner",
      "fr" => "Propriétaire démo",
      "vi" => "Chủ sở hữu mẫu"
    }.each do |locale, display_name|
      get localized_about_path(locale: locale)

      assert_select "h1", text: display_name
    end
  end

  test "unsupported locale segments return not found" do
    get "/de/about"

    assert_response :not_found
  end

  test "localized shell routes reject non-HTML formats" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/en/about.json")
    end
  end
end
