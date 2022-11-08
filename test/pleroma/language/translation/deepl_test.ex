# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Language.Translation.DeeplTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Language.Translation.Deepl

  test "it translates text" do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    clear_config([Pleroma.Language.Translation.Deepl, :base_url], "https://api-free.deepl.com")
    clear_config([Pleroma.Language.Translation.Deepl, :api_key], "API_KEY")

    {:ok, res} =
      Deepl.translate(
        "USUNĄĆ ŚLEDZIKA!Wklej to na swojego śledzika. Jeżeli uzbieramy 70% użytkowników nk...to usuną śledzika!!!",
        "pl",
        "en"
      )

    assert %{
             detected_source_language: "PL",
             provider: "DeepL"
           } = res
  end

  test "it returns languages list" do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    clear_config([Pleroma.Language.Translation.Deepl, :base_url], "https://api-free.deepl.com")
    clear_config([Pleroma.Language.Translation.Deepl, :api_key], "API_KEY")

    assert {:ok, [language | _languages]} = Deepl.supported_languages(:target)

    assert is_binary(language)
  end
end
