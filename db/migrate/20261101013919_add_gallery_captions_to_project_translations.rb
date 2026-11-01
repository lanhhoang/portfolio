class AddGalleryCaptionsToProjectTranslations < ActiveRecord::Migration[8.1]
  def change
    add_column :project_translations, :gallery_captions, :text, default: "", null: false
  end
end
