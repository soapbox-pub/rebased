# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.AppCreateRequest do
  alias OpenApiSpex.Schema
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "AppCreateRequest",
    description: "POST body for creating an app",
    type: :object,
    properties: %{
      client_name: %Schema{type: :string, description: "A name for your application."},
      redirect_uris: %Schema{
        type: :string,
        description:
          "Where the user should be redirected after authorization. To display the authorization code to the user instead of redirecting to a web page, use `urn:ietf:wg:oauth:2.0:oob` in this parameter."
      },
      scopes: %Schema{
        type: :string,
        description: "Space separated list of scopes. If none is provided, defaults to `read`."
      },
      website: %Schema{type: :string, description: "A URL to the homepage of your app"}
    },
    required: [:client_name, :redirect_uris],
    example: %{
      "client_name" => "My App",
      "redirect_uris" => "https://myapp.com/auth/callback",
      "website" => "https://myapp.com/"
    }
  })
end
