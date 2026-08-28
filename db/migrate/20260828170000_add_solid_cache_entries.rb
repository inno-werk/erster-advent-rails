class AddSolidCacheEntries < ActiveRecord::Migration[8.0]
  def up
    # Production uses one PostgreSQL database for primary and cache connections.
    # cache_schema.rb is not applied to an already initialized primary database.
    create_table :solid_cache_entries, if_not_exists: true do |t|
      t.binary :key, limit: 1024, null: false
      t.binary :value, limit: 536870912, null: false
      t.datetime :created_at, null: false
      t.bigint :key_hash, null: false
      t.integer :byte_size, null: false
    end

    unless index_exists?(:solid_cache_entries, :key_hash, unique: true)
      # Repair an existing non-unique index without replacing the table or its data.
      name = "index_solid_cache_entries_on_key_hash"
      remove_index :solid_cache_entries, name: name if index_name_exists?(:solid_cache_entries, name)
      add_index :solid_cache_entries, :key_hash, unique: true, name: name
    end

    add_index :solid_cache_entries, :byte_size unless index_exists?(:solid_cache_entries, :byte_size)
    unless index_exists?(:solid_cache_entries, [ :key_hash, :byte_size ])
      add_index :solid_cache_entries, [ :key_hash, :byte_size ]
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The cache table may predate this migration; preserve its data."
  end
end
