defmodule Pleroma.Repo.Migrations.AssignAppUser do
  use Ecto.Migration

  alias Pleroma.Repo
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Token

  def up do
    Repo.all(Token)
    |> Enum.group_by(fn x -> Map.get(x, :app_id) end)
    |> Enum.each(fn {_app_id, tokens} ->
      token =
        Enum.filter(tokens, fn x -> not is_nil(x.user_id) end)
        |> List.first()

      App.maybe_update_owner(token)
    end)
  end

  def down, do: :ok
end
