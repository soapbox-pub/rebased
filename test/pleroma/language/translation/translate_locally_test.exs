# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Language.Translation.TranslateLocallyTest do
  use Pleroma.DataCase

  alias Pleroma.Language.Translation.TranslateLocally

  @example_models %{
    "de" => %{
      "en" => "de-en-base"
    },
    "en" => %{
      "de" => "en-de-base",
      "pl" => "en-pl-tiny"
    },
    "cs" => %{
      "en" => "cs-en-base"
    },
    "pl" => %{
      "en" => "pl-en-tiny"
    }
  }

  test "it returns languages list" do
    clear_config([Pleroma.Language.Translation.TranslateLocally, :models], @example_models)

    assert {:ok, languages} = TranslateLocally.supported_languages(:source)
    assert ["cs", "de", "en", "pl"] = languages |> Enum.sort()
  end

  describe "it returns languages matrix" do
    test "without intermediary language" do
      clear_config([Pleroma.Language.Translation.TranslateLocally, :models], @example_models)

      assert {:ok,
              %{
                "cs" => ["en"],
                "de" => ["en"],
                "en" => ["de", "pl"],
                "pl" => ["en"]
              }} = TranslateLocally.languages_matrix()
    end

    test "with intermediary language" do
      clear_config([Pleroma.Language.Translation.TranslateLocally, :models], @example_models)
      clear_config([Pleroma.Language.Translation.TranslateLocally, :intermediary_language], "en")

      assert {:ok,
              %{
                "cs" => ["de", "en", "pl"],
                "de" => ["en", "pl"],
                "en" => ["de", "pl"],
                "pl" => ["de", "en"]
              }} = TranslateLocally.languages_matrix()
    end
  end
end
