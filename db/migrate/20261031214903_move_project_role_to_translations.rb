class MoveProjectRoleToTranslations < ActiveRecord::Migration[8.1]
  def up
    add_column :project_translations, :role, :string, null: false, default: ""
    add_column :project_translations, :outcome, :text, null: false, default: ""
    execute <<~SQL
      UPDATE project_translations
      SET role = (SELECT projects.role FROM projects WHERE projects.id = project_translations.project_id)
    SQL
    remove_column :projects, :role
  end

  def down
    add_column :projects, :role, :string, null: false, default: ""
    execute <<~SQL
      UPDATE projects
      SET role = COALESCE((
        SELECT project_translations.role FROM project_translations
        WHERE project_translations.project_id = projects.id AND project_translations.locale = 'en'
      ), '')
    SQL
    remove_column :project_translations, :outcome
    remove_column :project_translations, :role
  end
end
