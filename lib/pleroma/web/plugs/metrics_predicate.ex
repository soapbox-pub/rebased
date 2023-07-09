defmodule Pleroma.Web.Plugs.MetricsPredicate do
  @moduledoc """
  This Unplug predicate is used to authorize requests to the PromEx metrics
  """

  @behaviour Unplug.Predicate

  @impl true
  def call(conn, _) do
    conn
    |> Plug.Conn.get_req_header("authorization")
    |> case do
      ["Bearer " <> token] ->
        token == get_configured_auth_token()

      [] ->
        get_configured_auth_token() == :disabled

      _ ->
        false
    end
  end

  defp get_configured_auth_token do
    :pleroma
    |> Application.get_env(__MODULE__, auth_token: "super_secret")
    |> Keyword.get(:auth_token)
  end
end
