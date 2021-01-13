# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.SchemaExamplesTest do
  use ExUnit.Case, async: true
  import Pleroma.Tests.ApiSpecHelpers

  @content_type "application/json"

  for operation <- api_operations() do
    describe operation.operationId <> " Request Body" do
      if operation.requestBody do
        @media_type operation.requestBody.content[@content_type]
        @schema resolve_schema(@media_type.schema)

        if @media_type.example do
          test "request body media type example matches schema" do
            assert_schema(@media_type.example, @schema)
          end
        end

        if @schema.example do
          test "request body schema example matches schema" do
            assert_schema(@schema.example, @schema)
          end
        end
      end
    end

    for {status, response} <- operation.responses, is_map(response.content[@content_type]) do
      describe "#{operation.operationId} - #{status} Response" do
        @schema resolve_schema(response.content[@content_type].schema)

        if @schema.example do
          test "example matches schema" do
            assert_schema(@schema.example, @schema)
          end
        end
      end
    end
  end
end
