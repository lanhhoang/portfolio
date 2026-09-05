require "test_helper"

class Admin::ResumesTest < ActionDispatch::IntegrationTest
  setup { sign_in_as_admin }

  test "renders an empty editor without persisting a row" do
    assert_no_difference "Resume.count" do
      get edit_admin_resume_path
    end
    assert_response :success
  end

  test "first update creates the singleton plus its English translation with a PDF" do
    patch admin_resume_path, params: { resume: resume_params }

    resume = Resume.current
    assert_redirected_to edit_admin_resume_path, status: :see_other
    assert resume.translations.find_by!(locale: "en").pdf.attached?
    assert_equal Date.new(2026, 9, 2), resume.updated_on
  end

  test "second update keeps the same rows" do
    create_resume
    translation = Resume.current.translations.sole

    assert_no_difference [ "Resume.count", "ResumeTranslation.count" ] do
      patch admin_resume_path, params: { resume: resume_params.merge(
        translations_attributes: { "0" => { id: translation.id, locale: "en", title: "Résumé", description: "English résumé" } }
      ) }
    end

    assert_redirected_to edit_admin_resume_path
  end

  test "stores English and French text with a distinct PDF per translation" do
    patch admin_resume_path, params: { resume: resume_params }

    resume = Resume.current
    assert_equal %w[en fr], resume.translations.order(:locale).pluck(:locale)
    resume.translations.each { |translation| assert translation.pdf.attached? }
  end

  test "optional blank Vietnamese is rejected rather than persisted" do
    patch admin_resume_path, params: { resume: resume_params }

    assert_not_includes Resume.current.translations.pluck(:locale), "vi"
  end

  test "text/plain PDF upload returns 422 with text retained" do
    patch admin_resume_path, params: { resume: resume_params.merge(
      translations_attributes: {
        "0" => { locale: "en", title: "Résumé", description: "English résumé", pdf: Rack::Test::UploadedFile.new(Rails.root.join("Gemfile"), "text/plain") }
      }
    ) }

    assert_response :unprocessable_entity
    assert_select "input[value='Résumé']"
    assert_select "[role='alert']"
  end

  test "does not let nested updates move a persisted translation to another locale" do
    create_resume
    translation = Resume.current.translations.sole

    patch admin_resume_path, params: { resume: resume_params.merge(
      translations_attributes: { "0" => { id: translation.id, locale: "vi", title: "X", description: "X" } }
    ) }

    assert_response :see_other
    assert_equal "en", translation.reload.locale
  end

  test "rejects a malformed resume scope" do
    patch admin_resume_path, params: { resume: "not-an-object" }
    assert_response :bad_request
  end

  test "removing the French PDF cannot remove the English PDF" do
    create_resume
    resume = Resume.current
    english = resume.translations.find_by!(locale: "en")
    french = resume.translations.create!(locale: "fr", title: "CV", description: "CV français")
    english.pdf.attach(io: fixture_file_io, filename: "en.pdf", content_type: "application/pdf")
    french.pdf.attach(io: fixture_file_io, filename: "fr.pdf", content_type: "application/pdf")

    delete admin_resume_pdf_path(french)

    assert_redirected_to edit_admin_resume_path
    assert english.reload.pdf.attached?
    refute french.reload.pdf.attached?
  end

  test "renders localized PDF removal as standalone delete forms" do
    create_resume
    french = Resume.current.translations.create!(locale: "fr", title: "CV", description: "CV français")
    Resume.current.translations.find_by!(locale: "en").pdf.attach(io: fixture_file_io, filename: "en.pdf", content_type: "application/pdf")
    french.pdf.attach(io: fixture_file_io, filename: "fr.pdf", content_type: "application/pdf")

    get edit_admin_resume_path
    assert_select "form[action='#{admin_resume_pdf_path(french)}'][method='post']" do
      assert_select "input[name='_method'][value='delete']"
    end
    assert_select "form form", count: 0
    assert_select "a[data-turbo-method='delete']", count: 0
  end

  test "requires authentication" do
    sign_out_admin
    get edit_admin_resume_path
    assert_redirected_to new_admin_session_path
  end

  private

  def create_resume
    Resume.create!(updated_on: Date.new(2026, 9, 2), translations_attributes: {
      "0" => { locale: "en", title: "Résumé", description: "English résumé" }
    })
  end

  def resume_params
    {
      updated_on: "2026-09-02",
      translations_attributes: {
        "0" => { locale: "en", title: "Résumé", description: "English résumé", pdf: fixture_file_upload("resume.pdf", "application/pdf") },
        "1" => { locale: "fr", title: "CV", description: "CV français", pdf: fixture_file_upload("resume.pdf", "application/pdf") },
        "2" => { locale: "vi", title: "", description: "", pdf: nil }
      }
    }
  end

  def fixture_file_io
    StringIO.new(File.read(Rails.root.join("test/fixtures/files/resume.pdf")))
  end
end
