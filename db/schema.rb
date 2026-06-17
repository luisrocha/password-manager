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

ActiveRecord::Schema[8.1].define(version: 2026_06_17_120000) do
  create_table "credentials", force: :cascade do |t|
    t.string "category", default: "login", null: false
    t.datetime "created_at", null: false
    t.string "domain"
    t.text "encrypted_secret_payload", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["domain"], name: "index_credentials_on_domain"
    t.index ["name"], name: "index_credentials_on_name"
  end

  create_table "mobile_devices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.datetime "revoked_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["revoked_at"], name: "index_mobile_devices_on_revoked_at"
    t.index ["token_digest"], name: "index_mobile_devices_on_token_digest", unique: true
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", limit: 1024, null: false
    t.integer "channel_hash", limit: 8, null: false
    t.datetime "created_at", null: false
    t.binary "payload", limit: 536870912, null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "totp_remembered_clients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_totp_remembered_clients_on_expires_at"
    t.index ["token_digest"], name: "index_totp_remembered_clients_on_token_digest", unique: true
  end

  create_table "totp_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "enabled_at"
    t.text "recovery_code_digests", default: "[]", null: false
    t.string "secret", null: false
    t.datetime "updated_at", null: false
  end

  create_table "vault_signing_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "public_key_spki", null: false
    t.datetime "updated_at", null: false
  end

end
