class CreateAdminUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.text :totp_secret, null: false
      t.json :recovery_code_digests, null: false, default: []
      t.datetime :last_totp_at
      t.integer :singleton_guard, null: false, default: 1
      t.timestamps
    end

    add_index :admin_users, :email, unique: true
    add_index :admin_users, :singleton_guard, unique: true
    add_check_constraint :admin_users, "singleton_guard = 1", name: "admin_users_single_owner"
  end
end
