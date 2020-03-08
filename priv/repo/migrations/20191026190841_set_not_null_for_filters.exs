defmodule Pleroma.Repo.Migrations.SetNotNullForFilters do
  use Ecto.Migration

  # modify/3 function will require index recreation, so using execute/1 instead

  def up do
    execute("ALTER TABLE filters
    ALTER COLUMN user_id SET NOT NULL,
    ALTER COLUMN filter_id SET NOT NULL,
    ALTER COLUMN whole_word SET NOT NULL")
  end

  def down do
    execute("ALTER TABLE filters
    ALTER COLUMN user_id DROP NOT NULL,
    ALTER COLUMN filter_id DROP NOT NULL,
    ALTER COLUMN whole_word DROP NOT NULL")
  end
end
