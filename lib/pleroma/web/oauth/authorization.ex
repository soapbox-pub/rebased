defmodule Pleroma.Web.OAuth.Authorization do
  use Ecto.Schema

  alias Pleroma.{App, User, Repo}
  alias Pleroma.Web.OAuth.Authorization

  schema "oauth_authorizations" do
    field :token, :string
    field :valid_until, :naive_datetime
    field :used, :boolean, default: false
    belongs_to :user, Pleroma.User
    belongs_to :app, Pleroma.App

    timestamps()
  end

  def create_authorization(%App{} = app, %User{} = user) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64

    authorization = %Authorization{
      token: token,
      used: false,
      user_id: user.id,
      app_id: app.id,
      valid_until: NaiveDateTime.add(NaiveDateTime.utc_now, 60 * 10)
    }

    Repo.insert(authorization)
  end
end
