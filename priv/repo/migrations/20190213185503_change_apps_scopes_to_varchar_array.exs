defmodule Pleroma.Repo.Migrations.ChangeAppsScopesToVarcharArray do
  use Ecto.Migration

  @alter_apps_scopes "ALTER TABLE apps ALTER COLUMN scopes"

  def up do
    execute(
      "#{@alter_apps_scopes} TYPE varchar(255)[] USING string_to_array(scopes, ',')::varchar(255)[];"
    )

    execute("#{@alter_apps_scopes} SET DEFAULT ARRAY[]::character varying[];")
    execute("#{@alter_apps_scopes} SET NOT NULL;")
  end

  def down do
    execute("#{@alter_apps_scopes} DROP NOT NULL;")
    execute("#{@alter_apps_scopes} DROP DEFAULT;")

    execute(
      "#{@alter_apps_scopes} TYPE varchar(255) USING array_to_string(scopes, ',')::varchar(255);"
    )
  end
end
