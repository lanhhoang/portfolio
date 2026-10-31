class AddJobTitleToProfileTranslations < ActiveRecord::Migration[8.1]
  # Backfill with the wording the hero used while the title lived in locale files.
  PREVIOUS_TITLES = { "en" => "Product engineer", "fr" => "Ingénieur produit", "vi" => "Kỹ sư sản phẩm" }.freeze

  def up
    add_column :profile_translations, :job_title, :string, null: false, default: ""
    PREVIOUS_TITLES.each do |locale, title|
      execute "UPDATE profile_translations SET job_title = #{connection.quote(title)} WHERE locale = #{connection.quote(locale)}"
    end
  end

  def down
    remove_column :profile_translations, :job_title
  end
end
