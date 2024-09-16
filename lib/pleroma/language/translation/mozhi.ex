# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Language.Translation.Mozhi do
  import Pleroma.Web.Utils.Guards, only: [not_empty_string: 1]

  alias Pleroma.Language.Translation.Provider

  use Provider

  @behaviour Provider

  @name "Mozhi"

  @impl Provider
  def configured?, do: not_empty_string(base_url()) and not_empty_string(engine())

  @impl Provider
  def translate(content, source_language, target_language) do
    endpoint =
      base_url()
      |> URI.merge("/api/translate")
      |> URI.to_string()

    case Pleroma.HTTP.get(
           endpoint <>
             "?" <>
             URI.encode_query(%{
               engine: engine(),
               text: content,
               from: source_language,
               to: target_language
             }),
           [{"Accept", "application/json"}]
         ) do
      {:ok, %{status: 200} = res} ->
        %{
          "translated-text" => content,
          "source_language" => source_language
        } = Jason.decode!(res.body)

        {:ok,
         %{
           content: content,
           detected_source_language: source_language,
           provider: @name
         }}

      _ ->
        {:error, :internal_server_error}
    end
  end

  @impl Provider
  def supported_languages(type) when type in [:source, :target] do
    path =
      case type do
        :source -> "/api/source_languages"
        :target -> "/api/target_languages"
      end

    endpoint =
      base_url()
      |> URI.merge(path)
      |> URI.to_string()

    case Pleroma.HTTP.get(
           endpoint <>
             "?" <>
             URI.encode_query(%{
               engine: engine()
             }),
           [{"Accept", "application/json"}]
         ) do
      {:ok, %{status: 200} = res} ->
        languages =
          Jason.decode!(res.body)
          |> Enum.map(fn %{"Id" => language} -> language end)

        {:ok, languages}

      _ ->
        {:error, :internal_server_error}
    end
  end

  @impl Provider
  def languages_matrix do
    with {:ok, source_languages} <- supported_languages(:source),
         {:ok, target_languages} <- supported_languages(:target) do
      {:ok,
       Map.new(source_languages, fn language -> {language, target_languages -- [language]} end)}
    else
      {:error, error} -> {:error, error}
    end
  end

  @impl Provider
  def name, do: @name

  defp base_url do
    Pleroma.Config.get([__MODULE__, :base_url])
  end

  defp engine do
    Pleroma.Config.get([__MODULE__, :engine])
  end
end
