# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.Tag do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "Tag",
    description: "Represents a hashtag used within the content of a status",
    type: :object,
    properties: %{
      name: %Schema{type: :string, description: "The value of the hashtag after the # sign"},
      url: %Schema{
        type: :string,
        format: :uri,
        description: "A link to the hashtag on the instance"
      }
    },
    example: %{
      name: "cofe",
      url: "https://lain.com/tag/cofe"
    }
  })
end
