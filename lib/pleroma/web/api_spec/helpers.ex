# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Helpers do
  def request_body(description, schema_ref, opts \\ []) do
    media_types = ["application/json", "multipart/form-data"]

    content =
      media_types
      |> Enum.map(fn type ->
        {type,
         %OpenApiSpex.MediaType{
           schema: schema_ref,
           example: opts[:example],
           examples: opts[:examples]
         }}
      end)
      |> Enum.into(%{})

    %OpenApiSpex.RequestBody{
      description: description,
      content: content,
      required: opts[:required] || false
    }
  end
end
