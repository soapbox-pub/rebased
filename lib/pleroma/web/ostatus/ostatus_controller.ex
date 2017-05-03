defmodule Pleroma.Web.OStatus.OStatusController do
  use Pleroma.Web, :controller

  alias Pleroma.{User, Activity}
  alias Pleroma.Web.OStatus.{FeedRepresenter, ActivityRepresenter}
  alias Pleroma.Repo
  alias Pleroma.Web.OStatus
  import Ecto.Query

  def feed_redirect(conn, %{"nickname" => nickname}) do
    user = User.get_cached_by_nickname(nickname)
    redirect conn, external: OStatus.feed_path(user)
  end

  def feed(conn, %{"nickname" => nickname}) do
    user = User.get_cached_by_nickname(nickname)
    query = from activity in Activity,
      where: fragment("? @> ?", activity.data, ^%{actor: user.ap_id}),
      limit: 20,
      order_by: [desc: :inserted_at]

    activities = query
    |> Repo.all

    response = FeedRepresenter.to_simple_form(user, activities, [user])
    |> :xmerl.export_simple(:xmerl_xml)
    |> to_string

    conn
    |> put_resp_content_type("application/atom+xml")
    |> send_resp(200, response)
  end

  def salmon_incoming(conn, params) do
    {:ok, body, _conn} = read_body(conn)
    magic_key = Pleroma.Web.Salmon.fetch_magic_key(body)
    {:ok, doc} = Pleroma.Web.Salmon.decode_and_validate(magic_key, body)

    Pleroma.Web.OStatus.handle_incoming(doc)

    conn
    |> send_resp(200, "")
  end

  def object(conn, %{"uuid" => uuid}) do
    id = o_status_url(conn, :object, uuid)
    activity = Activity.get_create_activity_by_object_ap_id(id)
    user = User.get_cached_by_ap_id(activity.data["actor"])

    response = ActivityRepresenter.to_simple_form(activity, user, true)
    |> ActivityRepresenter.wrap_with_entry
    |> :xmerl.export_simple(:xmerl_xml)
    |> to_string

    conn
    |> put_resp_content_type("application/atom+xml")
    |> send_resp(200, response)
  end
end
