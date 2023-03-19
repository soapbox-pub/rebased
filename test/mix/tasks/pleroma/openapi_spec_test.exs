# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.OpenapiSpecTest do
  use Pleroma.DataCase, async: true

  alias Mix.Tasks.Pleroma.OpenapiSpec

  @spec_base %{
    "paths" => %{
      "/cofe" => %{
        "get" => %{
          "operationId" => "Some.operation",
          "tags" => []
        }
      },
      "/mew" => %{
        "post" => %{
          "operationId" => "Another.operation",
          "tags" => ["mew mew"]
        }
      }
    },
    "x-tagGroups" => [
      %{
        "name" => "mew",
        "tags" => ["mew mew", "abc"]
      },
      %{
        "name" => "lol",
        "tags" => ["lol lol", "xyz"]
      }
    ]
  }

  describe "check_specs/1" do
    test "Every operation must have a tag" do
      assert {:error, ["Some.operation (get /cofe): No tags specified"]} ==
               OpenapiSpec.check_specs(@spec_base)
    end

    test "Every tag must be in tag groups" do
      spec =
        @spec_base
        |> put_in(["paths", "/cofe", "get", "tags"], ["abc", "def", "not specified"])

      assert {:error,
              [
                "Some.operation (get /cofe): Tags #{inspect(["def", "not specified"])} not available. Please add it in \"x-tagGroups\" in Pleroma.Web.ApiSpec"
              ]} == OpenapiSpec.check_specs(spec)
    end

    test "No errors if ok" do
      spec =
        @spec_base
        |> put_in(["paths", "/cofe", "get", "tags"], ["abc", "mew mew"])

      assert :ok == OpenapiSpec.check_specs(spec)
    end
  end
end
