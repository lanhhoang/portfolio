# frozen_string_literal: true

module Public
  class ProfilesController < PublicController
    def show
      @profile = Profile.current || raise(ActiveRecord::RecordNotFound)
      @translation = @profile.translations.find_by!(locale: current_locale.to_s)
    end
  end
end
