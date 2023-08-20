# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.LocationResult do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "LocationResult",
    description: "Represents a location lookup result",
    type: :object,
    properties: %{
      country: %Schema{type: :string, description: "The address's country", nullable: true},
      description: %Schema{
        type: :string,
        description: "The address's description",
        nullable: true
      },
      locality: %Schema{type: :string, description: "The address's locality", nullable: true},
      origin_id: %Schema{
        type: :string,
        description: "The address's original ID from the provider",
        nullable: true
      },
      origin_provider: %Schema{
        type: :string,
        description: "The provider used  by instance",
        nullable: true
      },
      postal_code: %Schema{
        type: :string,
        description: "The address's postal code",
        nullable: true
      },
      region: %Schema{type: :string, description: "The address's region", nullable: true},
      street: %Schema{
        type: :string,
        description: "The address's street name (with number)",
        nullable: true
      },
      timezone: %Schema{
        type: :string,
        description: "The (estimated) timezone of the location",
        nullable: true
      },
      type: %Schema{type: :string, description: "The address's type", nullable: true},
      url: %Schema{type: :string, description: "The address's URL", nullable: true},
      geom: %Schema{
        type: :object,
        properties: %{
          coordinates: %Schema{
            type: :array,
            items: %Schema{type: :number}
          },
          srid: %Schema{type: :integer}
        },
        nullable: true
      }
    },
    example: %{
      "country" => "Poland",
      "description" => "Dworek Modrzewiowy",
      "geom" => %{
        "coordinates" => [19.35267765039501, 52.233616299999994],
        "srid" => 4326
      },
      "locality" => "Kutno",
      "origin_id" => "251399743",
      "origin_provider" => "nominatim",
      "postal_code" => "80-549",
      "region" => "Łódź Voivodeship",
      "street" => "20 Gabriela Narutowicza",
      "timezone" => nil,
      "type" => "house",
      "url" => nil
    }
  })
end
