# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Language.Translation.TranslateLocally do
  alias Pleroma.Language.Translation.Provider

  use Provider

  @behaviour Provider

  @name "translateLocally"

  @impl Provider
  def missing_dependencies do
    if Pleroma.Utils.command_available?("translateLocally") do
      []
    else
      ["translateLocally"]
    end
  end

  @impl Provider
  def configured?, do: is_map(models())

  @impl Provider
  def translate(content, source_language, target_language) do
    model =
      models()
      |> Map.get(source_language, %{})
      |> Map.get(target_language)

    models =
      if model do
        [model]
      else
        [
          models()
          |> Map.get(source_language, %{})
          |> Map.get(intermediary_language()),
          models()
          |> Map.get(intermediary_language(), %{})
          |> Map.get(target_language)
        ]
      end

    translated_content =
      Enum.reduce(models, content, fn model, content ->
        text_path = Path.join(System.tmp_dir!(), "translateLocally-#{Ecto.UUID.generate()}")

        File.write(text_path, content)

        translated_content =
          case System.cmd("translateLocally", ["-m", model, "-i", text_path, "--html"]) do
            {content, _} -> content
            _ -> nil
          end

        File.rm(text_path)

        translated_content
      end)

    {:ok,
     %{
       content: translated_content,
       detected_source_language: source_language,
       provider: @name
     }}
  end

  @impl Provider
  def supported_languages(:source) do
    languages =
      languages_matrix()
      |> elem(1)
      |> Map.keys()

    {:ok, languages}
  end

  @impl Provider
  def supported_languages(:target) do
    languages =
      languages_matrix()
      |> elem(1)
      |> Map.values()
      |> List.flatten()
      |> Enum.uniq()

    {:ok, languages}
  end

  @impl Provider
  def languages_matrix do
    languages =
      models()
      |> Map.to_list()
      |> Enum.map(fn {key, value} -> {key, Map.keys(value)} end)
      |> Enum.into(%{})

    matrix =
      if intermediary_language() do
        languages
        |> Map.to_list()
        |> Enum.map(fn {key, value} ->
          with_intermediary =
            (((value ++ languages[intermediary_language()])
              |> Enum.uniq()) --
               [key])
            |> Enum.sort()

          {key, with_intermediary}
        end)
        |> Enum.into(%{})
      else
        languages
      end

    {:ok, matrix}
  end

  @impl Provider
  def name, do: @name

  defp models, do: Pleroma.Config.get([__MODULE__, :models])

  defp intermediary_language, do: Pleroma.Config.get([__MODULE__, :intermediary_language])
end
