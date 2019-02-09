defmodule Pleroma.Repo.Migrations.AddScopeToOAuthEntities do
  use Ecto.Migration

  def change do
    for t <- [:oauth_authorizations, :oauth_tokens] do
      alter table(t) do
        add :scope, :string
      end
    end
  end
end
