defmodule Pleroma.Web.OStatus.OStatusController do
  use Pleroma.Web, :controller

  alias Pleroma.{User, Activity}
  alias Pleroma.Web.OStatus.FeedRepresenter
  alias Pleroma.Repo
  import Ecto.Query

  def feed(conn, %{"nickname" => nickname}) do
    user = User.get_cached_by_nickname(nickname)
    query = from activity in Activity,
      where: fragment("? @> ?", activity.data, ^%{actor: user.ap_id}),
      limit: 20,
      order_by: [desc: :inserted_at]

    activities = query
    |> Repo.all

    response = user
    |> FeedRepresenter.to_simple_form(activities, [user])
    |> :xmerl.export_simple(:xmerl_xml)
    |> to_string

    conn
    |> put_resp_content_type("application/atom+xml")
    |> send_resp(200, response)
  end

  def temp(_conn, params) do
    IO.inspect(params)
  end
end
