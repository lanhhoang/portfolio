class CreatePostTranslations < ActiveRecord::Migration[8.1]
  LOCALES = "'en', 'fr', 'vi'"
  STATES = "'draft', 'scheduled', 'published'"

  def change
    create_table :post_translations do |t|
      t.references :post, null: false, foreign_key: true, index: false
      t.string :locale, null: false
      t.string :title, null: false
      t.string :slug, null: false
      t.text :excerpt, null: false
      t.text :body_markdown, null: false
      t.text :body_html, null: false, default: ""
      t.text :search_text, null: false, default: ""
      t.string :state, null: false, default: "draft"
      t.datetime :scheduled_at
      t.datetime :published_at
      t.timestamps
      t.index %i[post_id locale], unique: true
      t.index %i[locale slug], unique: true
      t.index %i[locale state published_at], name: :index_post_translations_public_listing
      t.check_constraint "locale IN (#{LOCALES})", name: "post_translations_locale"
      t.check_constraint "state IN (#{STATES})", name: "post_translations_state"
    end
  end
end
