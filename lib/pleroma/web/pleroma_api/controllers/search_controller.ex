# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.SearchController do
  use Pleroma.Web, :controller

  alias Pleroma.Web.Plugs.OAuthScopesPlug

  require Pleroma.Constants

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(OAuthScopesPlug, %{scopes: [], op: :&} when action in [:location])

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaSearchOperation

  def location(conn, %{q: query} = params) do
    result = Geospatial.Service.service().search(query, params |> Map.to_list())

    render(conn, "index_locations.json", locations: result)
  end
end
