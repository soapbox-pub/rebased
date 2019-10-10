defmodule Pleroma.Repo.Migrations.DataMigrationNormalizeScopes do
  use Ecto.Migration

  def up do
    for t <- [:apps, :oauth_authorizations, :oauth_tokens] do
      execute("UPDATE #{t} SET scopes = string_to_array(array_to_string(scopes, ' '), ' ');")
    end
  end

  def down, do: :noop
end
