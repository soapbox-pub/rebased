# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Language.LanguageDetector do
  @words_threshold 4

  def missing_dependencies do
    provider = get_provider()

    if provider do
      provider.missing_dependencies()
    else
      []
    end
  end

  # Strip tags from text, etc.
  defp prepare_text(text) do
    text
    |> Floki.parse_fragment!()
    |> Floki.filter_out(
      ".h-card, .mention, .hashtag, .u-url, .quote-inline, .recipients-inline, code, pre"
    )
    |> Floki.text()
  end

  def detect(text) do
    provider = get_provider()

    text = prepare_text(text)
    word_count = text |> String.split(~r/\s+/) |> Enum.count()

    if word_count < @words_threshold or !provider or !provider.configured? do
      nil
    else
      provider.detect(text)
    end
  end

  defp get_provider do
    Pleroma.Config.get([__MODULE__, :provider])
  end
end
