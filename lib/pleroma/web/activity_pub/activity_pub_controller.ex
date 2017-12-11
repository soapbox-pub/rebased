defmodule Pleroma.Web.ActivityPub.ActivityPubController do
  use Pleroma.Web, :controller
  alias Pleroma.{User, Repo}
  alias Pleroma.Web.ActivityPub.UserView
  alias Pleroma.Web.ActivityPub.ActivityPub

  def user(conn, %{"nickname" => nickname}) do
    with %User{} = user <- User.get_cached_by_nickname(nickname) do
      json(conn, UserView.render("user.json", %{user: user}))
    end
  end

  def inbox(conn, params) do
    {:ok, activity} = ActivityPub.insert(params, false)
    json(conn, "ok")
  end
end
