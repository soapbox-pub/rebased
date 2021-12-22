# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.UtilView do
  use Pleroma.Web, :view
  import Phoenix.HTML.Form
  alias Pleroma.Config
  alias Pleroma.Web.Endpoint

  def status_net_config(instance) do
    """
    <config>
    <site>
    <name>#{Keyword.get(instance, :name)}</name>
    <site>#{Endpoint.url()}</site>
    <textlimit>#{Keyword.get(instance, :limit)}</textlimit>
    <closed>#{!Keyword.get(instance, :registrations_open)}</closed>
    </site>
    </config>
    """
  end

  def render("frontend_configurations.json", _) do
    Config.get(:frontend_configurations, %{})
    |> Enum.into(%{})
  end
end
