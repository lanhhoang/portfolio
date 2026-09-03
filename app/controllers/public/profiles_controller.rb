# frozen_string_literal: true

module Public
  class ProfilesController < PublicController
    def show
      @profile = Profile.current || raise(ActiveRecord::RecordNotFound)
      @translation = @profile.translations.find_by!(locale: current_locale.to_s)
      @locale_switch_paths = @profile.translations.pluck(:locale).index_with do |locale|
        localized_about_path(locale: locale)
      end
    end
  end
end
