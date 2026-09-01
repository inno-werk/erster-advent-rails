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

ActiveRecord::Schema[8.0].define(version: 2026_08_31_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "businesses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "business_name", null: false
    t.string "phone", null: false
    t.text "address", null: false
    t.text "billing_address", null: false
    t.string "main_image"
    t.string "image_gallery1"
    t.string "image_gallery2"
    t.string "image_gallery3"
    t.text "map_link", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "confirmed", default: false, null: false
    t.jsonb "categories", default: [], null: false
    t.string "contact_name", default: "", null: false
    t.string "email", default: "", null: false
    t.string "website", default: "", null: false
    t.string "instagram", default: "", null: false
    t.string "tiktok", default: "", null: false
    t.string "linkedin", default: "", null: false
    t.string "facebook", default: "", null: false
    t.integer "status", default: 0
    t.index ["categories"], name: "index_businesses_on_categories", using: :gin
    t.index ["confirmed"], name: "index_businesses_on_confirmed"
    t.index ["status"], name: "index_businesses_on_status"
    t.index ["user_id"], name: "index_businesses_on_user_id"
  end

  create_table "cms_blocks", force: :cascade do |t|
    t.string "page", default: "home", null: false
    t.integer "position", default: 0, null: false
    t.integer "block_type", null: false
    t.boolean "is_active", default: true, null: false
    t.string "button_url"
    t.string "button_text"
    t.text "question"
    t.text "answer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "image_position", default: "left", null: false
    t.index ["page", "position"], name: "index_cms_blocks_on_page_and_position"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "id_of_user", null: false
    t.integer "quantity", null: false
    t.string "size", null: false
    t.string "order_no", null: false
    t.string "accept_order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["id_of_user"], name: "index_orders_on_id_of_user"
    t.index ["product_id"], name: "index_orders_on_product_id"
  end

  create_table "participation_upgrades", force: :cascade do |t|
    t.bigint "participation_id", null: false
    t.string "previous_category", null: false
    t.integer "previous_amount_cents", null: false
    t.string "category", null: false
    t.integer "amount_cents", null: false
    t.integer "difference_cents", null: false
    t.string "payment_status", default: "pending", null: false
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "payment_provider"
    t.string "payment_reference"
    t.index ["participation_id"], name: "index_participation_upgrades_on_participation_id"
    t.index ["participation_id"], name: "one_pending_upgrade_per_participation", unique: true, where: "((payment_status)::text = 'pending'::text)"
    t.check_constraint "payment_status::text = 'pending'::text AND paid_at IS NULL OR payment_status::text = 'paid'::text AND paid_at IS NOT NULL", name: "participation_upgrades_payment_state"
    t.check_constraint "previous_amount_cents >= 0 AND difference_cents > 0 AND amount_cents = (previous_amount_cents + difference_cents)", name: "participation_upgrades_valid_difference"
  end

  create_table "participations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "year", null: false
    t.string "category", null: false
    t.integer "amount_cents", null: false
    t.string "payment_status", default: "pending", null: false
    t.datetime "selected_at", null: false
    t.datetime "paid_at"
    t.string "payment_provider"
    t.string "payment_reference"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "year"], name: "index_participations_on_user_id_and_year", unique: true
    t.index ["user_id"], name: "index_participations_on_user_id"
    t.check_constraint "amount_cents >= 0", name: "participations_nonnegative_amount"
    t.check_constraint "category::text = ANY (ARRAY['leist_member'::character varying, 'non_leist_member'::character varying, 'no_listing'::character varying]::text[])", name: "participations_valid_category"
    t.check_constraint "payment_status::text = 'pending'::text AND paid_at IS NULL OR payment_status::text = 'paid'::text AND paid_at IS NOT NULL", name: "participations_payment_state"
    t.check_constraint "year >= 2000 AND year <= 9999", name: "participations_valid_year"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "payment_image", null: false
    t.string "payment_session_id"
    t.string "customer_email"
    t.string "plan"
    t.string "is_verified", default: "Pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "print_distributions", force: :cascade do |t|
    t.integer "year", null: false
    t.date "distribution_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "order_deadline_on"
    t.index ["year"], name: "index_print_distributions_on_year", unique: true
  end

  create_table "print_order_items", force: :cascade do |t|
    t.bigint "print_order_id", null: false
    t.bigint "print_product_id", null: false
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["print_order_id", "print_product_id"], name: "index_print_order_items_on_print_order_id_and_print_product_id", unique: true
    t.index ["print_order_id"], name: "index_print_order_items_on_print_order_id"
    t.index ["print_product_id"], name: "index_print_order_items_on_print_product_id"
    t.check_constraint "quantity > 0", name: "print_order_items_positive_quantity"
  end

  create_table "print_orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "year", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "year"], name: "index_print_orders_on_user_id_and_year", unique: true
    t.index ["user_id"], name: "index_print_orders_on_user_id"
    t.check_constraint "year >= 2000 AND year <= 9999", name: "print_orders_valid_year"
  end

  create_table "print_products", force: :cascade do |t|
    t.string "title", null: false
    t.text "description", null: false
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.string "seed_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["seed_key"], name: "index_print_products_on_seed_key", unique: true
    t.check_constraint "\"position\" >= 0", name: "print_products_nonnegative_position"
  end

  create_table "products", force: :cascade do |t|
    t.string "title", null: false
    t.text "description", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.string "main_product_image", null: false
    t.jsonb "images_of_product", null: false
    t.jsonb "sizes", null: false
    t.string "delievry_time", null: false
    t.integer "total_orders", default: 0, null: false
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_products_on_user_id"
  end

  create_table "site_settings", force: :cascade do |t|
    t.string "brand_color", default: "#52819C", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "stripe_payments", force: :cascade do |t|
    t.bigint "participation_id", null: false
    t.bigint "participation_upgrade_id"
    t.string "payment_kind", null: false
    t.string "obligation_key", null: false
    t.integer "attempt", null: false
    t.integer "amount_cents", null: false
    t.string "currency", default: "chf", null: false
    t.string "status", default: "pending", null: false
    t.string "idempotency_key", null: false
    t.string "checkout_session_id"
    t.text "checkout_url"
    t.string "payment_intent_id"
    t.datetime "expires_at"
    t.datetime "paid_at"
    t.string "failure_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checkout_session_id"], name: "index_stripe_payments_on_checkout_session_id", unique: true
    t.index ["idempotency_key"], name: "index_stripe_payments_on_idempotency_key", unique: true
    t.index ["obligation_key", "attempt"], name: "index_stripe_payments_on_obligation_key_and_attempt", unique: true
    t.index ["obligation_key"], name: "one_active_stripe_payment_per_obligation", unique: true, where: "((status)::text = ANY ((ARRAY['pending'::character varying, 'checkout_created'::character varying, 'processing'::character varying])::text[]))"
    t.index ["participation_id"], name: "index_stripe_payments_on_participation_id"
    t.index ["participation_upgrade_id"], name: "index_stripe_payments_on_participation_upgrade_id"
    t.index ["payment_intent_id"], name: "index_stripe_payments_on_payment_intent_id", unique: true
    t.check_constraint "amount_cents > 0", name: "stripe_payments_positive_amount"
  end

  create_table "stripe_webhook_events", force: :cascade do |t|
    t.string "stripe_event_id", null: false
    t.string "event_type", null: false
    t.string "status", default: "received", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.text "processing_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stripe_event_id"], name: "index_stripe_webhook_events_on_stripe_event_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
    t.string "business_name"
    t.text "address"
    t.string "management_name"
    t.string "phone"
    t.string "category"
    t.integer "package_plan"
    t.string "otp"
    t.boolean "is_verified", default: false, null: false
    t.datetime "otp_expiration_time"
    t.string "payment_method"
    t.string "legacy_password_hash"
    t.boolean "deleted", default: false, null: false
    t.index "to_tsvector('simple'::regconfig, (COALESCE(email, ''::character varying))::text)", name: "users_search_idx", using: :gin
    t.index ["deleted"], name: "index_users_on_deleted"
    t.index ["email"], name: "index_users_on_email", opclass: :gin_trgm_ops, using: :gin
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "businesses", "users"
  add_foreign_key "orders", "products"
  add_foreign_key "orders", "users", column: "id_of_user"
  add_foreign_key "participation_upgrades", "participations"
  add_foreign_key "participations", "users"
  add_foreign_key "payments", "users"
  add_foreign_key "print_order_items", "print_orders"
  add_foreign_key "print_order_items", "print_products"
  add_foreign_key "print_orders", "users"
  add_foreign_key "products", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "stripe_payments", "participation_upgrades"
  add_foreign_key "stripe_payments", "participations"
end
