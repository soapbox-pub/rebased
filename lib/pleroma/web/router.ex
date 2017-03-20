defmodule Pleroma.Web.Router do
  use Pleroma.Web, :router

  alias Pleroma.{Repo, User}

  def user_fetcher(username) do
    {:ok, Repo.get_by(User, %{nickname: username})}
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug Pleroma.Plugs.AuthenticationPlug, fetcher: &Pleroma.Web.Router.user_fetcher/1
  end

  scope "/api", Pleroma.Web do
    pipe_through :authenticated_api

    post "/account/verify_credentials.json", TwitterAPI.Controller, :verify_credentials
  end
end
