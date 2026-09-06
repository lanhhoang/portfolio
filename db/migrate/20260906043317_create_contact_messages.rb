# frozen_string_literal: true

class CreateContactMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_messages do |t|
      t.string :sender_name, null: false
      t.string :sender_email, null: false
      t.string :subject, null: false
      t.text :body, null: false
      t.string :state, null: false, default: "unread"
      t.string :email_delivery_state, null: false, default: "pending"
      t.datetime :delivered_at
      t.string :last_delivery_error
      t.timestamps

      t.check_constraint "state IN ('unread', 'read', 'archived')", name: "contact_messages_valid_state"
      t.check_constraint "email_delivery_state IN ('pending', 'delivered', 'failed')",
        name: "contact_messages_valid_delivery_state"
      t.check_constraint <<~SQL.squish, name: "contact_messages_consistent_delivery_state"
        (email_delivery_state = 'pending' AND delivered_at IS NULL AND last_delivery_error IS NULL) OR
        (email_delivery_state = 'delivered' AND delivered_at IS NOT NULL AND last_delivery_error IS NULL) OR
        (email_delivery_state = 'failed' AND delivered_at IS NULL AND last_delivery_error IS NOT NULL)
      SQL
    end

    add_index :contact_messages, [:state, :created_at]
    add_index :contact_messages, [:email_delivery_state, :created_at], name: "index_contact_messages_on_delivery_state_and_created_at"
  end
end
