class CreateShortLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :short_links do |t|
      # Slug: 50 character limit with case-insensitive uniqueness
      t.string :slug, null: false, limit: 50

      # Destination URL (up to 2048 characters)
      t.text :destination, null: false

      # Flag to indicate if slug is custom (user-chosen) or auto-generated
      t.boolean :custom, default: false, null: false

      t.timestamps
    end

    # Add case-insensitive unique index on slug
    # For SQLite: Use COLLATE NOCASE
    # For PostgreSQL/MySQL: Use functional index on LOWER(slug)
    if connection.adapter_name.downcase.include?('sqlite')
      # SQLite uses COLLATE NOCASE for case-insensitive indexes
      execute "CREATE UNIQUE INDEX index_short_links_on_slug_lower ON short_links (slug COLLATE NOCASE)"
    else
      # PostgreSQL/MySQL use functional indexes
      add_index :short_links, "LOWER(slug)", unique: true, name: "index_short_links_on_slug_lower"
    end
  end
end
