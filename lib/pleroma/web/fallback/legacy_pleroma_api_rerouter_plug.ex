# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Fallback.LegacyPleromaApiRerouterPlug do
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Fallback.RedirectController

  def init(opts), do: opts

  def call(%{path_info: ["api", "pleroma" | path_info_rest]} = conn, _opts) do
    new_path_info = ["api", "v1", "pleroma" | path_info_rest]
    new_request_path = Enum.join(new_path_info, "/")

    conn
    |> Map.merge(%{
      path_info: new_path_info,
      request_path: new_request_path
    })
    |> Endpoint.call(conn.params)
  end

  def call(conn, _opts) do
    RedirectController.api_not_implemented(conn, %{})
  end
end
