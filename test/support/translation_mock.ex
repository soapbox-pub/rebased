# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule TranslationMock do
  alias Pleroma.Language.Translation.Provider

  use Provider

  @behaviour Provider

  @name "TranslationMock"

  @impl Provider
  def configured?, do: true

  @impl Provider
  def translate(content, source_language, _target_language) do
    {:ok,
     %{
       content: content |> String.reverse(),
       detected_source_language: source_language,
       provider: @name
     }}
  end

  @impl Provider
  def supported_languages(_) do
    {:ok, ["en", "pl"]}
  end

  @impl Provider
  def languages_matrix do
    {:ok,
     %{
       "en" => ["pl"],
       "pl" => ["en"]
     }}
  end

  @impl Provider
  def name, do: @name
end
