# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ManifestController do
  use Pleroma.Web, :controller

  plug(:skip_auth when action == :show)

  @doc "GET /manifest.json"
  def show(conn, _params) do
    render(conn, "manifest.json")
  end
end
