# frozen_string_literal: true

module Public
  class ResumesController < PublicController
    def show
      load_translation
    end

    private

    def load_translation
      @resume = Resume.current || raise(ActiveRecord::RecordNotFound)
      @translation = @resume.translations.find_by!(locale: current_locale.to_s)
      @locale_switch_paths = @resume.translations.pluck(:locale).index_with do |locale|
        localized_resume_path(locale: locale)
      end
    end
  end
end
