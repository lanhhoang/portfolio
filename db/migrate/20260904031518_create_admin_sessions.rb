class CreateAdminSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_sessions do |t|
      t.references :admin_user, null: false, foreign_key: true
      t.string :state, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :admin_sessions, :expires_at
    add_check_constraint :admin_sessions,
      "state IN ('pending_totp', 'verified')",
      name: "admin_sessions_valid_state"
  end
end
