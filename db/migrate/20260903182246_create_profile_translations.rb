class CreateProfileTranslations < ActiveRecord::Migration[8.1]
  LOCALES = "'en', 'fr', 'vi'"

  def change
    create_table :profile_translations do |t|
      t.references :profile, null: false, foreign_key: true, index: false
      t.string :locale, null: false
      t.string :display_name, null: false
      t.string :headline, null: false
      t.text :introduction, null: false
      t.text :biography_markdown, null: false
      t.text :biography_html, null: false, default: ""
      t.string :availability_label, null: false
      t.timestamps
      t.index %i[profile_id locale], unique: true
      t.check_constraint "locale IN (#{LOCALES})", name: "profile_translations_locale"
    end
  end
end
