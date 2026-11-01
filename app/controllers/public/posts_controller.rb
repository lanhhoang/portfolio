# frozen_string_literal: true

module Public
  class PostsController < PublicController
    def index
      @translations = PostTranslation.filtered(
        locale: current_locale, query: params[:q], tag_slug: params[:tag]
      )
      @tag_translations = available_tags
      @search_offered = search_offered?(PostTranslation.publicly_visible(locale: current_locale))
    end

    def show
      @translation = PostTranslation.publicly_visible(locale: current_locale)
        .includes(post: { tags: :translations })
        .find_by!(slug: params[:slug])
      @newer_translation, @older_translation = adjacent_translations
      build_locale_switch_paths
    end

    private

    # Neighbours in index order (newest first); nil at either end.
    def adjacent_translations
      ordered = PostTranslation.publicly_visible(locale: current_locale).order(published_at: :desc, id: :desc)
      ids = ordered.pluck(:id)
      position = ids.index(@translation.id)
      newer_id = ids[position - 1] if position.positive?
      older_id = ids[position + 1]
      found = ordered.where(id: [ newer_id, older_id ].compact).index_by(&:id)
      [ found[newer_id], found[older_id] ]
    end

    def available_tags
      visible_ids = PostTranslation.publicly_visible(locale: current_locale).select(:post_id)

      TagTranslation.joins(tag: :taggings)
        .where(locale: current_locale.to_s)
        .where(taggings: { taggable_type: "Post", taggable_id: visible_ids })
        .distinct
        .order(:name)
    end

    def build_locale_switch_paths
      @locale_switch_paths = {}
      sibling_slugs = @translation.post.translations
        .where(state: "published")
        .where("published_at <= ?", Time.current)
        .pluck(:locale, :slug)
      sibling_slugs.each do |locale, slug|
        @locale_switch_paths[locale] = localized_post_path(locale: locale, slug: slug)
      end
    end
  end
end
