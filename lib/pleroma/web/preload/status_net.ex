# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Preload.Providers.StatusNet do
  alias Pleroma.Web.Preload.Providers.Provider
  alias Pleroma.Web.TwitterAPI.UtilController

  @behaviour Provider
  @config_url "/api/statusnet/config.json"

  @impl Provider
  def generate_terms(_params) do
    %{}
    |> build_config_tag()
  end

  defp build_config_tag(acc) do
    resp =
      Plug.Test.conn(:get, @config_url |> to_string())
      |> UtilController.config(nil)

    Map.put(acc, @config_url, resp.resp_body)
  end
end
