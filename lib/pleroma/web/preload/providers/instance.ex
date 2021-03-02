# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Preload.Providers.Instance do
  alias Pleroma.Web.MastodonAPI.InstanceView
  alias Pleroma.Web.Nodeinfo.Nodeinfo
  alias Pleroma.Web.Plugs.InstanceStatic
  alias Pleroma.Web.Preload.Providers.Provider
  alias Pleroma.Web.TwitterAPI.UtilView

  @behaviour Provider
  @instance_url "/api/v1/instance"
  @panel_url "/instance/panel.html"
  @nodeinfo_url "/nodeinfo/2.0.json"
  @fe_config_url "/api/pleroma/frontend_configurations"

  @impl Provider
  def generate_terms(_params) do
    %{}
    |> build_info_tag()
    |> build_panel_tag()
    |> build_nodeinfo_tag()
    |> build_fe_config_tag()
  end

  defp build_info_tag(acc) do
    info_data = InstanceView.render("show.json", %{})

    Map.put(acc, @instance_url, info_data)
  end

  defp build_panel_tag(acc) do
    instance_path = InstanceStatic.file_path(@panel_url |> to_string())

    if File.exists?(instance_path) do
      panel_data = File.read!(instance_path)
      Map.put(acc, @panel_url, panel_data)
    else
      acc
    end
  end

  defp build_nodeinfo_tag(acc) do
    case Nodeinfo.get_nodeinfo("2.0") do
      {:error, _} ->
        acc

      nodeinfo_data ->
        Map.put(acc, @nodeinfo_url, nodeinfo_data)
    end
  end

  defp build_fe_config_tag(acc) do
    fe_data = UtilView.render("frontend_configurations.json", %{})

    Map.put(acc, @fe_config_url, fe_data)
  end
end
