# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule TranslationMock do
  alias Pleroma.Language.Translation.Provider

  @behaviour Provider

  @impl Provider
  def configured?, do: true

  @impl Provider
  def translate(content, source_language, _target_language) do
    {:ok,
     %{
       content: content |> String.reverse(),
       detected_source_language: source_language,
       provider: "TranslationMock"
     }}
  end
end
