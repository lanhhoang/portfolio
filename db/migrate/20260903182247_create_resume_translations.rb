class CreateResumeTranslations < ActiveRecord::Migration[8.1]
  LOCALES = "'en', 'fr', 'vi'"

  def change
    create_table :resume_translations do |t|
      t.references :resume, null: false, foreign_key: true, index: false
      t.string :locale, null: false
      t.string :title, null: false
      t.text :description, null: false
      t.timestamps
      t.index %i[resume_id locale], unique: true
      t.check_constraint "locale IN (#{LOCALES})", name: "resume_translations_locale"
    end
  end
end
