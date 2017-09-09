defmodule Pleroma.Web.MastodonAPI.MastodonAPIController do
  use Pleroma.Web, :controller
  alias Pleroma.{Repo, Activity}
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web
  alias Pleroma.Web.MastodonAPI.{StatusView, AccountView}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.TwitterAPI.TwitterAPI

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

  def home_timeline(%{assigns: %{user: user}} = conn, params) do
    activities = ActivityPub.fetch_activities([user.ap_id | user.following], Map.put(params, "type", "Create"))
    render conn, StatusView, "index.json", %{activities: activities, for: user, as: :activity}
  end

  def public_timeline(%{assigns: %{user: user}} = conn, params) do
    params = params
    |> Map.put("type", "Create")
    |> Map.put("local_only", !!params["local"])

    activities = ActivityPub.fetch_public_activities(params)

    render conn, StatusView, "index.json", %{activities: activities, for: user, as: :activity}
  end

  def get_status(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    with %Activity{} = activity <- Repo.get(Activity, id) do
      render conn, StatusView, "status.json", %{activity: activity, for: user}
    end
  end

  def post_status(%{assigns: %{user: user}} = conn, %{"status" => status} = params) do
    l = status |> String.trim |> String.length

    params = params
    |> Map.put("in_reply_to_status_id", params["in_reply_to_id"])

    if l > 0 && l < 5000 do
      {:ok, activity} = TwitterAPI.create_status(user, params)
      render conn, StatusView, "status.json", %{activity: activity, for: user, as: :activity}
    end
  end
end
