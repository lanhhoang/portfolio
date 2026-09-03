class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles do |t|
      t.string :public_contact_email, null: false
      t.json :social_links, null: false, default: {}
      t.string :accent, null: false, default: "lime"
      t.integer :singleton_guard, null: false, default: 1
      t.timestamps
      t.index :singleton_guard, unique: true
      t.check_constraint "singleton_guard = 1", name: "profiles_singleton"
      t.check_constraint "accent IN ('brown', 'green', 'lime', 'orange', 'yellow')",
        name: "profiles_accent"
    end
  end
end
