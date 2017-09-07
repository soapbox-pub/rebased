defmodule Pleroma.Web.MastodonAPI.MastodonAPIController do
  use Pleroma.Web, :controller
  alias Pleroma.{Repo}
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web
  alias Pleroma.Web.MastodonAPI.AccountView

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
    account = AccountView.render("account.json", %{user: user})
    json(conn, account)
  end

  def masto_instance(conn, _params) do
    response = %{
      uri: Web.base_url,
      title: Web.base_url,
      description: "A Pleroma instance, an alternative fediverse server",
      version: "Pleroma Dev"
    }

    json(conn, response)
  end
end
