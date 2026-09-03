# frozen_string_literal: true

module Public
  class PostsController < PublicController
    def index
      @translations = PostTranslation.filtered(
        locale: current_locale, query: params[:q], tag_slug: params[:tag]
      )
      @tag_translations = available_tags
    end

    def show
      @translation = PostTranslation.publicly_visible(locale: current_locale)
        .includes(post: { tags: :translations })
        .find_by!(slug: params[:slug])
      build_locale_switch_paths
    end

    private

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
      @locale_switch_paths[@translation.locale] = localized_post_path(locale: current_locale, slug: params[:slug])
    end
  end
end
