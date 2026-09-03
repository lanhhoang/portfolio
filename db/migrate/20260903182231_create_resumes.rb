class CreateResumes < ActiveRecord::Migration[8.1]
  def change
    create_table :resumes do |t|
      t.date :updated_on, null: false
      t.integer :singleton_guard, null: false, default: 1
      t.timestamps
      t.index :singleton_guard, unique: true
      t.check_constraint "singleton_guard = 1", name: "resumes_singleton"
    end
  end
end
