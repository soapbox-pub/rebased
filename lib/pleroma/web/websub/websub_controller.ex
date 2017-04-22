defmodule Pleroma.Web.Websub.WebsubController do
  use Pleroma.Web, :controller
  alias Pleroma.User
  alias Pleroma.Web.Websub

  def websub_subscription_request(conn, %{"nickname" => nickname} = params) do
    user = User.get_cached_by_nickname(nickname)

    with {:ok, _websub} <- Websub.incoming_subscription_request(user, params)
    do
      conn
      |> send_resp(202, "Accepted")
    else {:error, reason} ->
      conn
      |> send_resp(500, reason)
    end
  end
end
