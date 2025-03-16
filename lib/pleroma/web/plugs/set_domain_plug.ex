# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.SetDomainPlug do
  use Pleroma.Web, :plug

  alias Pleroma.Domain

  def init(opts), do: opts

  @impl true
  def perform(%{host: domain} = conn, _opts) do
    with true <- Pleroma.Config.get([:instance, :multitenancy, :enabled], false),
         false <-
           domain in [
             Pleroma.Config.get([__MODULE__, :domain]),
             Pleroma.Web.Endpoint.host()
           ],
         %Domain{} = domain <- Domain.get_by_name(domain) do
      Map.put(conn, :domain, domain)
    else
      _ -> conn
    end
  end

  def perform(conn, _), do: conn
end
