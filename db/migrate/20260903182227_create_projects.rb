class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :role, null: false
      t.date :started_on
      t.date :ended_on
      t.string :live_url
      t.string :source_url
      t.integer :featured_position
      t.timestamps
      t.index :featured_position
      t.check_constraint "featured_position IS NULL OR featured_position > 0",
        name: "projects_featured_position_positive"
    end
  end
end
