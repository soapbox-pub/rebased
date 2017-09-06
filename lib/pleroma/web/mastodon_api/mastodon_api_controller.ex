defmodule Pleroma.Web.MastodonAPI.MastodonAPIController do
  use Pleroma.Web, :controller
  alias Pleroma.{Repo, App}

  def create_app(conn, params) do
    with cs <- App.register_changeset(%App{}, params) |> IO.inspect,
         {:ok, app} <- Repo.insert(cs) |> IO.inspect do
      res = %{
        id: app.id,
        client_id: app.client_id,
        client_secret: app.client_secret
      }

      json(conn, res)
    end
  end

  def verify_credentials(%{assigns: %{user: user}} = conn, params) do
    account = %{
      id: user.id,
      username: user.nickname,
      acct: user.nickname,
      display_name: user.name,
      locked: false,
      created_at: user.inserted_at,
      note: user.bio,
      url: ""
    }

    json(conn, account)
  end
end
