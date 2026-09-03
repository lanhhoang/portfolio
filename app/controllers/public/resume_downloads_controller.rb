# frozen_string_literal: true

module Public
  class ResumeDownloadsController < PublicController
    def show
      resume = Resume.current || raise(ActiveRecord::RecordNotFound)
      translation = resume.translations.find_by!(locale: current_locale.to_s)
      raise ActiveRecord::RecordNotFound unless translation.pdf.attached?

      redirect_to rails_blob_path(translation.pdf, disposition: "attachment")
    end
  end
end
