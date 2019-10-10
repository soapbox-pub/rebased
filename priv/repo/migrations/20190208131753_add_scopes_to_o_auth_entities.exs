defmodule Pleroma.Repo.Migrations.AddScopeSToOAuthEntities do
  use Ecto.Migration

  def change do
    for t <- [:oauth_authorizations, :oauth_tokens] do
      alter table(t) do
        add(:scopes, {:array, :string}, default: [], null: false)
      end
    end
  end
end
