# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Scopes.CompilerTest do
  use ExUnit.Case, async: true

  alias Pleroma.Web.ApiSpec.Scopes.Compiler

  @dummy_response %{}

  @data %{
    paths: %{
      "/mew" => %OpenApiSpex.PathItem{
        post: %OpenApiSpex.Operation{
          security: [%{"oAuth" => ["a:b:c"]}],
          responses: @dummy_response
        },
        get: %OpenApiSpex.Operation{security: nil, responses: @dummy_response}
      },
      "/mew2" => %OpenApiSpex.PathItem{
        post: %OpenApiSpex.Operation{
          security: [%{"oAuth" => ["d:e", "f:g"]}],
          responses: @dummy_response
        },
        get: %OpenApiSpex.Operation{security: nil, responses: @dummy_response}
      }
    }
  }

  describe "process_scope/1" do
    test "gives all higher-level scopes" do
      scopes = Compiler.process_scope("admin:read:accounts")

      assert [_, _, _] = scopes
      assert "admin" in scopes
      assert "admin:read" in scopes
      assert "admin:read:accounts" in scopes
    end
  end

  describe "extract_all_scopes_from/1" do
    test "extracts scopes" do
      scopes = Compiler.extract_all_scopes_from(@data)

      assert [_, _, _, _, _, _, _] = scopes
      assert "a" in scopes
      assert "a:b" in scopes
      assert "a:b:c" in scopes
      assert "d" in scopes
      assert "d:e" in scopes
      assert "f" in scopes
      assert "f:g" in scopes
    end
  end
end
