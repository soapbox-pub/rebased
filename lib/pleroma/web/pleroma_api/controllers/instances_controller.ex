# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.InstancesController do
  use Pleroma.Web, :controller

  alias Pleroma.Instances

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaInstancesOperation

  def show(conn, _params) do
    unreachable =
      Instances.get_consistently_unreachable()
      |> Map.new(fn {host, date} -> {host, to_string(date)} end)

    json(conn, %{"unreachable" => unreachable})
  end
end
