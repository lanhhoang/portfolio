class CreateTagTranslations < ActiveRecord::Migration[8.1]
  LOCALES = "'en', 'fr', 'vi'"

  def change
    create_table :tag_translations do |t|
      t.references :tag, null: false, foreign_key: true, index: false
      t.string :locale, null: false
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
      t.index %i[tag_id locale], unique: true
      t.index %i[locale slug], unique: true
      t.check_constraint "locale IN (#{LOCALES})", name: "tag_translations_locale"
    end
  end
end
