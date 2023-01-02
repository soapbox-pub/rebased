# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.App do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "App",
    description: "Response schema for an app",
    type: :object,
    properties: %{
      id: %Schema{type: :string},
      name: %Schema{type: :string},
      client_id: %Schema{type: :string},
      client_secret: %Schema{type: :string},
      redirect_uri: %Schema{type: :string},
      vapid_key: %Schema{type: :string},
      website: %Schema{type: :string, nullable: true}
    },
    example: %{
      "id" => "123",
      "name" => "My App",
      "client_id" => "TWhM-tNSuncnqN7DBJmoyeLnk6K3iJJ71KKXxgL1hPM",
      "client_secret" => "ZEaFUFmF0umgBX1qKJDjaU99Q31lDkOU8NutzTOoliw",
      "vapid_key" =>
        "BCk-QqERU0q-CfYZjcuB6lnyyOYfJ2AifKqfeGIm7Z-HiTU5T9eTG5GxVA0_OH5mMlI4UkkDTpaZwozy0TzdZ2M=",
      "website" => "https://myapp.com/"
    }
  })
end
