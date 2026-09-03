class CreateTaggings < ActiveRecord::Migration[8.1]
  def change
    create_table :taggings do |t|
      t.references :tag, null: false, foreign_key: true, index: false
      t.references :taggable, null: false, polymorphic: true,
        index: { name: :index_taggings_on_taggable }
      t.timestamps
      t.index %i[tag_id taggable_type taggable_id], unique: true,
        name: :index_taggings_uniqueness
    end
  end
end
