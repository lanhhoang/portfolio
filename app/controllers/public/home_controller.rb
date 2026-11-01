# frozen_string_literal: true

module Public
  class HomeController < PublicController
    def show
      @profile = Profile.current
      @profile_translation = @profile&.translations&.find_by(locale: current_locale.to_s)
      @projects = ProjectTranslation.publicly_visible(locale: current_locale)
        .joins(:project)
        .where.not(projects: { featured_position: nil })
        .order("projects.featured_position ASC")
        .limit(4)
      @posts = PostTranslation.publicly_visible(locale: current_locale)
        .order(published_at: :desc)
        .limit(5)
      resume_translation = Resume.current&.translations&.find_by(locale: current_locale.to_s)
      @resume_pdf = resume_translation.pdf if resume_translation&.pdf&.attached?
    end
  end
end
