defmodule Pleroma.Repo.Migrations.DataMigrationPopulateOAuthScopes do
  use Ecto.Migration

  require Ecto.Query

  alias Ecto.Query
  alias Pleroma.Repo
  alias Pleroma.Web.OAuth
  alias Pleroma.Web.OAuth.{App, Authorization, Token}

  def up do
    for app <- Repo.all(Query.from(app in App)) do
      scopes = OAuth.parse_scopes(app.scopes)

      Repo.update_all(
        Query.from(auth in Authorization, where: auth.app_id == ^app.id),
        set: [scopes: scopes]
      )

      Repo.update_all(
        Query.from(token in Token, where: token.app_id == ^app.id),
        set: [scopes: scopes]
      )
    end
  end

  def down, do: :noop
end
