# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AkkomaCompatControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "translation_languages" do
    test "returns supported languages list", %{conn: conn} do
      clear_config([Pleroma.Language.Translation, :provider], TranslationMock)

      assert %{
               "source" => [%{"code" => "en", "name" => "en"}, %{"code" => "pl", "name" => "pl"}],
               "target" => [%{"code" => "en", "name" => "en"}, %{"code" => "pl", "name" => "pl"}]
             } =
               conn
               |> get("/api/v1/akkoma/translation/languages")
               |> json_response_and_validate_schema(200)
    end

    test "returns empty object when disabled", %{conn: conn} do
      clear_config([Pleroma.Language.Translation, :provider], nil)

      assert %{} ==
               conn
               |> get("/api/v1/akkoma/translation/languages")
               |> json_response(200)
    end
  end

  describe "translate" do
    test "it translates a status to given language" do
      clear_config([Pleroma.Language.Translation, :provider], TranslationMock)

      %{conn: conn} = oauth_access(["read:statuses"])
      another_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(another_user, %{
          status: "Cześć!",
          visibility: "public",
          language: "pl"
        })

      response =
        conn
        |> get("/api/v1/statuses/#{activity.id}/translations/en")
        |> json_response_and_validate_schema(200)

      assert response == %{
               "text" => "!ćśezC",
               "detected_language" => "pl"
             }
    end
  end
end
