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

ActiveRecord::Schema[8.1].define(version: 2026_02_26_154500) do
  create_table "credentials", force: :cascade do |t|
    t.string "category", default: "login", null: false
    t.datetime "created_at", null: false
    t.string "domain"
    t.string "name", null: false
    t.text "notes"
    t.text "password"
    t.datetime "updated_at", null: false
    t.text "username"
    t.index ["domain"], name: "index_credentials_on_domain"
    t.index ["name"], name: "index_credentials_on_name"
  end
end
