# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.DomainView do
  use Pleroma.Web, :view

  alias Pleroma.Domain

  def render("index.json", %{domains: domains}) do
    render_many(domains, __MODULE__, "show.json")
  end

  def render("show.json", %{domain: %Domain{id: id, domain: domain, public: public}}) do
    %{
      id: id |> to_string(),
      domain: domain,
      public: public
    }
  end
end
