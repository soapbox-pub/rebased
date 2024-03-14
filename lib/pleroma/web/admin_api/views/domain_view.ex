# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.DomainView do
  use Pleroma.Web, :view

  alias Pleroma.Domain
  alias Pleroma.Web.CommonAPI.Utils

  def render("index.json", %{domains: domains} = assigns) do
    render_many(domains, __MODULE__, "show.json", assigns |> Map.delete("domains"))
  end

  def render("show.json", %{domain: %Domain{} = domain} = assigns) do
    %{
      id: domain.id |> to_string(),
      domain: domain.domain,
      public: domain.public
    }
    |> maybe_put_resolve_information(domain, assigns)
  end

  defp maybe_put_resolve_information(map, _domain, %{admin: false}) do
    map
  end

  defp maybe_put_resolve_information(map, domain, _assigns) do
    map
    |> Map.merge(%{
      resolves: domain.resolves,
      last_checked_at: Utils.to_masto_date(domain.last_checked_at)
    })
  end
end
