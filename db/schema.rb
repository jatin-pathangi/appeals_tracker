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

ActiveRecord::Schema[8.1].define(version: 2026_02_21_060121) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "agenda_items", force: :cascade do |t|
    t.string "apn"
    t.bigint "council_meeting_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "item_number"
    t.string "item_type"
    t.string "project_address"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["council_meeting_id"], name: "index_agenda_items_on_council_meeting_id"
  end

  create_table "agenda_sources", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "agenda_url", null: false
    t.bigint "city_id", null: false
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "fetcher_class", null: false
    t.datetime "last_fetched_at"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_agenda_sources_on_active"
    t.index ["city_id"], name: "index_agenda_sources_on_city_id"
  end

  create_table "cities", force: :cascade do |t|
    t.string "county"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "state_code", default: "CA", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_cities_on_name"
    t.index ["slug"], name: "index_cities_on_slug", unique: true
  end

  create_table "council_meetings", force: :cascade do |t|
    t.bigint "agenda_source_id", null: false
    t.datetime "created_at", null: false
    t.datetime "fetched_at"
    t.date "meeting_date", null: false
    t.string "meeting_type", default: "regular", null: false
    t.string "pdf_url"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["agenda_source_id", "meeting_date"], name: "index_council_meetings_on_agenda_source_id_and_meeting_date", unique: true
    t.index ["agenda_source_id"], name: "index_council_meetings_on_agenda_source_id"
    t.index ["status"], name: "index_council_meetings_on_status"
  end

  create_table "housing_appeals", force: :cascade do |t|
    t.bigint "agenda_item_id"
    t.string "apn"
    t.string "appellant_name"
    t.bigint "city_id", null: false
    t.datetime "created_at", null: false
    t.string "decision"
    t.date "decision_date"
    t.date "filed_date"
    t.string "grounds_category"
    t.text "grounds_description"
    t.string "project_address"
    t.string "project_name"
    t.string "reference_number"
    t.string "status", default: "filed", null: false
    t.text "summary"
    t.datetime "updated_at", null: false
    t.index ["agenda_item_id"], name: "index_housing_appeals_on_agenda_item_id"
    t.index ["city_id", "reference_number"], name: "index_housing_appeals_on_city_id_and_reference_number", unique: true
    t.index ["city_id"], name: "index_housing_appeals_on_city_id"
    t.index ["filed_date"], name: "index_housing_appeals_on_filed_date"
    t.index ["status"], name: "index_housing_appeals_on_status"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agenda_items", "council_meetings"
  add_foreign_key "agenda_sources", "cities"
  add_foreign_key "council_meetings", "agenda_sources"
  add_foreign_key "housing_appeals", "agenda_items"
  add_foreign_key "housing_appeals", "cities"
end
