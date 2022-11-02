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
      nil
    end
  end

  def detect(text) do
    provider = get_provider()

    {:ok, text} = text |> FastSanitize.strip_tags()
    word_count = text |> String.split(~r/\s+/) |> Enum.count()

    if word_count < @words_threshold or !provider or !provider.configured? do
      nil
    else
      provider.detect(text)
    end
  end

  defp get_provider() do
    Pleroma.Config.get([__MODULE__, :provider])
  end
end
