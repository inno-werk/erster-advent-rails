require "test_helper"
require_relative "../../db/migrate/20260828170000_add_solid_cache_entries"

class SolidCacheSchemaTest < ActiveSupport::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
    @migration = AddSolidCacheEntries.new
  end

  teardown do
    SolidCache::Entry.reset_column_information
  end

  test "migration creates the missing cache table and all required indexes" do
    # PostgreSQL rolls this DDL back with the test transaction.
    @connection.drop_table(:solid_cache_entries)
    migrate
    assert @connection.table_exists?(:solid_cache_entries)
    assert @connection.index_exists?(:solid_cache_entries, :key_hash, unique: true)
    assert @connection.index_exists?(:solid_cache_entries, :byte_size)
    assert @connection.index_exists?(:solid_cache_entries, [ :key_hash, :byte_size ])
    assert_cache_upsert
  end

  test "migration repairs missing indexes without removing existing entries" do
    SolidCache::Entry.write("existing-entry", "keep this value")
    @connection.indexes(:solid_cache_entries).each do |index|
      @connection.remove_index(:solid_cache_entries, name: index.name)
    end
    SolidCache::Entry.reset_column_information
    error = assert_raises(ArgumentError) { SolidCache::Entry.write("broken-write", "value") }
    assert_equal "No unique index found for key_hash", error.message
    migrate
    assert_equal "keep this value", SolidCache::Entry.read("existing-entry")
    assert_cache_upsert
  end

  test "migration replaces a non-unique key hash index and is safe to rerun" do
    name = "index_solid_cache_entries_on_key_hash"
    @connection.remove_index(:solid_cache_entries, name: name)
    @connection.add_index(:solid_cache_entries, :key_hash, name: name)
    migrate
    SolidCache::Entry.write("existing-entry", "keep this value")
    migrate
    assert_equal "keep this value", SolidCache::Entry.read("existing-entry")
    assert @connection.index_exists?(:solid_cache_entries, :key_hash, unique: true)
    assert_cache_upsert
  end

  private

  def migrate
    ActiveRecord::Migration.suppress_messages { @migration.migrate(:up) }
    SolidCache::Entry.reset_column_information
  end

  def assert_cache_upsert
    SolidCache::Entry.write("upsert-probe", "before")
    SolidCache::Entry.write("upsert-probe", "after")
    assert_equal "after", SolidCache::Entry.read("upsert-probe")
  end
end
