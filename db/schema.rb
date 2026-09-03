# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_03_182247) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "post_translations", force: :cascade do |t|
    t.text "body_html", default: "", null: false
    t.text "body_markdown", null: false
    t.datetime "created_at", null: false
    t.text "excerpt", null: false
    t.string "locale", null: false
    t.integer "post_id", null: false
    t.datetime "published_at"
    t.datetime "scheduled_at"
    t.text "search_text", default: "", null: false
    t.string "slug", null: false
    t.string "state", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["locale", "slug"], name: "index_post_translations_on_locale_and_slug", unique: true
    t.index ["locale", "state", "published_at"], name: "index_post_translations_public_listing"
    t.index ["post_id", "locale"], name: "index_post_translations_on_post_id_and_locale", unique: true
    t.check_constraint "locale IN ('en', 'fr', 'vi')", name: "post_translations_locale"
    t.check_constraint "state IN ('draft', 'scheduled', 'published')", name: "post_translations_state"
  end

  create_table "posts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "profile_translations", force: :cascade do |t|
    t.string "availability_label", null: false
    t.text "biography_html", default: "", null: false
    t.text "biography_markdown", null: false
    t.datetime "created_at", null: false
    t.string "display_name", null: false
    t.string "headline", null: false
    t.text "introduction", null: false
    t.string "locale", null: false
    t.integer "profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id", "locale"], name: "index_profile_translations_on_profile_id_and_locale", unique: true
    t.check_constraint "locale IN ('en', 'fr', 'vi')", name: "profile_translations_locale"
  end

  create_table "profiles", force: :cascade do |t|
    t.string "accent", default: "lime", null: false
    t.datetime "created_at", null: false
    t.string "public_contact_email", null: false
    t.integer "singleton_guard", default: 1, null: false
    t.json "social_links", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["singleton_guard"], name: "index_profiles_on_singleton_guard", unique: true
    t.check_constraint "accent IN ('brown', 'green', 'lime', 'orange', 'yellow')", name: "profiles_accent"
    t.check_constraint "singleton_guard = 1", name: "profiles_singleton"
  end

  create_table "project_translations", force: :cascade do |t|
    t.text "body_html", default: "", null: false
    t.text "body_markdown", null: false
    t.datetime "created_at", null: false
    t.string "locale", null: false
    t.integer "project_id", null: false
    t.datetime "published_at"
    t.datetime "scheduled_at"
    t.text "search_text", default: "", null: false
    t.string "slug", null: false
    t.string "state", default: "draft", null: false
    t.text "summary", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["locale", "slug"], name: "index_project_translations_on_locale_and_slug", unique: true
    t.index ["locale", "state", "published_at"], name: "index_project_translations_public_listing"
    t.index ["project_id", "locale"], name: "index_project_translations_on_project_id_and_locale", unique: true
    t.check_constraint "locale IN ('en', 'fr', 'vi')", name: "project_translations_locale"
    t.check_constraint "state IN ('draft', 'scheduled', 'published')", name: "project_translations_state"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "ended_on"
    t.integer "featured_position"
    t.string "live_url"
    t.string "role", null: false
    t.string "source_url"
    t.date "started_on"
    t.datetime "updated_at", null: false
    t.index ["featured_position"], name: "index_projects_on_featured_position"
    t.check_constraint "featured_position IS NULL OR featured_position > 0", name: "projects_featured_position_positive"
  end

  create_table "resume_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "locale", null: false
    t.integer "resume_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["resume_id", "locale"], name: "index_resume_translations_on_resume_id_and_locale", unique: true
    t.check_constraint "locale IN ('en', 'fr', 'vi')", name: "resume_translations_locale"
  end

  create_table "resumes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "singleton_guard", default: 1, null: false
    t.datetime "updated_at", null: false
    t.date "updated_on", null: false
    t.index ["singleton_guard"], name: "index_resumes_on_singleton_guard", unique: true
    t.check_constraint "singleton_guard = 1", name: "resumes_singleton"
  end

  create_table "tag_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "locale", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["locale", "slug"], name: "index_tag_translations_on_locale_and_slug", unique: true
    t.index ["tag_id", "locale"], name: "index_tag_translations_on_tag_id_and_locale", unique: true
    t.check_constraint "locale IN ('en', 'fr', 'vi')", name: "tag_translations_locale"
  end

  create_table "taggings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "tag_id", null: false
    t.integer "taggable_id", null: false
    t.string "taggable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id", "taggable_type", "taggable_id"], name: "index_taggings_uniqueness", unique: true
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "post_translations", "posts"
  add_foreign_key "profile_translations", "profiles"
  add_foreign_key "project_translations", "projects"
  add_foreign_key "resume_translations", "resumes"
  add_foreign_key "tag_translations", "tags"
  add_foreign_key "taggings", "tags"
end
