# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Language.TranslationTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Language.Translation

  setup do: clear_config([Pleroma.Language.Translation, :provider], TranslationMock)

  test "it translates text" do
    assert {:ok,
            %{
              content: "txet emos",
              detected_source_language: _,
              provider: _
            }} = Translation.translate("some text", "en", "uk")
  end

  test "it stores translation result in cache" do
    Translation.translate("some text", "en", "uk")

    assert {:ok, result} =
             Cachex.get(
               :translations_cache,
               "en/uk/#{:crypto.hash(:sha256, "some text") |> Base.encode64()}"
             )

    assert result.content == "txet emos"
  end
end
