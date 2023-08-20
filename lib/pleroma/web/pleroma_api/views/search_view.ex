# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.SearchView do
  use Pleroma.Web, :view

  def render("index_locations.json", %{locations: locations}) do
    render_many(locations, __MODULE__, "show_location.json", as: :location)
  end

  def render("show_location.json", %{location: location}) do
    %{
      url: location.url,
      description: location.description,
      geom: render("geom.json", %{geom: location.geom}),
      country: location.country,
      locality: location.locality,
      region: location.region,
      postal_code: location.postal_code,
      street: location.street,
      origin_id: "#{location.origin_id}",
      origin_provider: location.origin_provider,
      type: location.type,
      timezone: location.timezone
    }
  end

  def render("geom.json", %{
        geom: %Geo.Point{coordinates: {longitude, latitude}, properties: _properties, srid: srid}
      }) do
    %{coordinates: [longitude, latitude], srid: srid}
  end

  def render("geom.json", %{geom: _}), do: nil
end
