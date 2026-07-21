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

ActiveRecord::Schema[8.1].define(version: 2026_07_21_103002) do
  create_table "active_storage_attachments", charset: "utf8mb4", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8mb4", force: :cascade do |t|
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

  create_table "active_storage_variant_records", charset: "utf8mb4", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_users", charset: "utf8mb4", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "candidate_documents", charset: "utf8mb4", force: :cascade do |t|
    t.bigint "candidate_profile_id", null: false
    t.string "content_type"
    t.datetime "created_at", null: false
    t.integer "document_type", default: 0, null: false
    t.bigint "file_size"
    t.string "original_filename"
    t.datetime "parsed_at"
    t.text "parsing_error"
    t.integer "parsing_method"
    t.integer "parsing_status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_profile_id"], name: "index_candidate_documents_on_candidate_profile_id"
  end

  create_table "candidate_languages", charset: "utf8mb4", force: :cascade do |t|
    t.bigint "candidate_profile_id", null: false
    t.datetime "created_at", null: false
    t.bigint "language_id", null: false
    t.string "level"
    t.datetime "updated_at", null: false
    t.index ["candidate_profile_id", "language_id"], name: "idx_on_candidate_profile_id_language_id_e7df01ffda", unique: true
    t.index ["candidate_profile_id"], name: "index_candidate_languages_on_candidate_profile_id"
    t.index ["language_id"], name: "index_candidate_languages_on_language_id"
  end

  create_table "candidate_profiles", charset: "utf8mb4", force: :cascade do |t|
    t.string "access_token"
    t.date "available_from"
    t.json "available_working_days", null: false
    t.integer "average_daily_revenue"
    t.string "big_number"
    t.integer "big_registration_status"
    t.string "city"
    t.datetime "completed_at"
    t.datetime "consent_given_at"
    t.string "country"
    t.datetime "created_at", null: false
    t.integer "desired_gross_salary"
    t.integer "desired_percentage"
    t.string "email"
    t.json "employment_types", null: false
    t.string "first_name"
    t.text "internal_notes"
    t.bigint "job_function_id"
    t.string "last_name"
    t.integer "max_travel_time"
    t.text "motivation"
    t.string "notice_period"
    t.string "onboarding_step", default: "cv_upload", null: false
    t.string "phone_number"
    t.json "preferred_regions", null: false
    t.text "professional_summary"
    t.text "reason_for_looking"
    t.integer "search_status"
    t.json "transport_types", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.integer "years_of_experience"
    t.index ["access_token"], name: "index_candidate_profiles_on_access_token", unique: true
    t.index ["email"], name: "index_candidate_profiles_on_email"
    t.index ["job_function_id"], name: "index_candidate_profiles_on_job_function_id"
    t.index ["user_id"], name: "index_candidate_profiles_on_user_id"
  end

  create_table "candidate_skills", charset: "utf8mb4", force: :cascade do |t|
    t.bigint "candidate_profile_id", null: false
    t.datetime "created_at", null: false
    t.bigint "skill_id"
    t.integer "source", default: 0, null: false
    t.string "suggested_name"
    t.datetime "updated_at", null: false
    t.index ["candidate_profile_id", "skill_id"], name: "index_candidate_skills_on_candidate_profile_id_and_skill_id", unique: true
    t.index ["candidate_profile_id"], name: "index_candidate_skills_on_candidate_profile_id"
    t.index ["skill_id"], name: "index_candidate_skills_on_skill_id"
  end

  create_table "educations", charset: "utf8mb4", force: :cascade do |t|
    t.bigint "candidate_profile_id", null: false
    t.string "city_and_country"
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "institution"
    t.integer "level"
    t.boolean "needs_review", default: false, null: false
    t.integer "source", default: 0, null: false
    t.date "start_date"
    t.string "study", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_profile_id"], name: "index_educations_on_candidate_profile_id"
  end

  create_table "job_functions", charset: "utf8mb4", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "clinical_group", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_job_functions_on_name", unique: true
  end

  create_table "languages", charset: "utf8mb4", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_languages_on_code", unique: true
  end

  create_table "skills", charset: "utf8mb4", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_function_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["job_function_id", "name"], name: "index_skills_on_job_function_id_and_name", unique: true
    t.index ["job_function_id"], name: "index_skills_on_job_function_id"
  end

  create_table "users", charset: "utf8mb4", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "work_experiences", charset: "utf8mb4", force: :cascade do |t|
    t.bigint "candidate_profile_id", null: false
    t.string "company_name", null: false
    t.datetime "created_at", null: false
    t.boolean "current_job", default: false, null: false
    t.date "end_date"
    t.string "job_title", null: false
    t.boolean "needs_review", default: false, null: false
    t.text "responsibilities"
    t.integer "source", default: 0, null: false
    t.date "start_date"
    t.datetime "updated_at", null: false
    t.index ["candidate_profile_id"], name: "index_work_experiences_on_candidate_profile_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "candidate_documents", "candidate_profiles"
  add_foreign_key "candidate_languages", "candidate_profiles"
  add_foreign_key "candidate_languages", "languages"
  add_foreign_key "candidate_profiles", "job_functions"
  add_foreign_key "candidate_profiles", "users"
  add_foreign_key "candidate_skills", "candidate_profiles"
  add_foreign_key "candidate_skills", "skills"
  add_foreign_key "educations", "candidate_profiles"
  add_foreign_key "skills", "job_functions"
  add_foreign_key "work_experiences", "candidate_profiles"
end
