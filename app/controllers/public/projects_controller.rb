# frozen_string_literal: true

module Public
  class ProjectsController < PublicController
    def index
      @translations = ProjectTranslation.filtered(
        locale: current_locale, query: params[:q], tag_slug: params[:tag]
      )
      @tag_translations = available_tags
    end

    def show
      @translation = ProjectTranslation.publicly_visible(locale: current_locale)
        .includes(project: { tags: :translations })
        .find_by!(slug: params[:slug])
      @next_translation = next_translation
      build_locale_switch_paths
    end

    private

    # The case study after this one in index order, wrapping to the first.
    def next_translation
      ordered = ProjectTranslation.publicly_visible(locale: current_locale).order(published_at: :desc, id: :desc)
      ids = ordered.pluck(:id)
      return if ids.size < 2

      ordered.find(ids[(ids.index(@translation.id) + 1) % ids.size])
    end

    def available_tags
      visible_ids = ProjectTranslation.publicly_visible(locale: current_locale).select(:project_id)

      TagTranslation.joins(tag: :taggings)
        .where(locale: current_locale.to_s)
        .where(taggings: { taggable_type: "Project", taggable_id: visible_ids })
        .distinct
        .order(:name)
    end

    def build_locale_switch_paths
      @locale_switch_paths = {}
      sibling_slugs = @translation.project.translations
        .where(state: "published")
        .where("published_at <= ?", Time.current)
        .pluck(:locale, :slug)
      sibling_slugs.each do |locale, slug|
        @locale_switch_paths[locale] = localized_project_path(locale: locale, slug: slug)
      end
    end
  end
end
