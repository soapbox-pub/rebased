# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Language.LanguageDetector.Fasttext do
  import Pleroma.Web.Utils.Guards, only: [not_empty_string: 1]

  alias Pleroma.Language.LanguageDetector.Provider

  @behaviour Provider

  @impl Provider
  def missing_dependencies do
    if Pleroma.Utils.command_available?("fasttext") do
      []
    else
      ["fasttext"]
    end
  end

  @impl Provider
  def configured?, do: not_empty_string(get_model())

  @impl Provider
  def detect(text) do
    text_path = Path.join(System.tmp_dir!(), "fasttext-#{Ecto.UUID.generate()}")

    File.write(text_path, text |> String.replace(~r/\s+/, " "))

    detected_language =
      case System.cmd("fasttext", ["predict", get_model(), text_path]) do
        {"__label__" <> language, _} ->
          language |> String.trim()

        _ ->
          nil
      end

    File.rm(text_path)

    detected_language
  end

  defp get_model do
    Pleroma.Config.get([__MODULE__, :model])
  end
end
