# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Language.Translation.Deepl do
  import Pleroma.Web.Utils.Guards, only: [not_empty_string: 1]

  alias Pleroma.Language.Translation.Provider

  use Provider

  @behaviour Provider

  @name "DeepL"

  @impl Provider
  def configured?, do: not_empty_string(base_url()) and not_empty_string(api_key())

  @impl Provider
  def translate(content, source_language, target_language) do
    endpoint =
      base_url()
      |> URI.merge("/v2/translate")
      |> URI.to_string()

    case Pleroma.HTTP.post(
           endpoint <>
             "?" <>
             URI.encode_query(%{
               text: content,
               source_lang: source_language |> String.upcase(),
               target_lang: target_language,
               tag_handling: "html"
             }),
           "",
           [
             {"Content-Type", "application/x-www-form-urlencoded"},
             {"Authorization", "DeepL-Auth-Key #{api_key()}"}
           ]
         ) do
      {:ok, %{status: 429}} ->
        {:error, :too_many_requests}

      {:ok, %{status: 456}} ->
        {:error, :quota_exceeded}

      {:ok, %{status: 200} = res} ->
        %{
          "translations" => [
            %{"text" => content, "detected_source_language" => detected_source_language}
          ]
        } = Jason.decode!(res.body)

        {:ok,
         %{
           content: content,
           detected_source_language: detected_source_language,
           provider: @name
         }}

      _ ->
        {:error, :internal_server_error}
    end
  end

  @impl Provider
  def supported_languages(type) when type in [:source, :target] do
    endpoint =
      base_url()
      |> URI.merge("/v2/languages")
      |> URI.to_string()

    case Pleroma.HTTP.post(
           endpoint <> "?" <> URI.encode_query(%{type: type}),
           "",
           [
             {"Content-Type", "application/x-www-form-urlencoded"},
             {"Authorization", "DeepL-Auth-Key #{api_key()}"}
           ]
         ) do
      {:ok, %{status: 200} = res} ->
        languages =
          Jason.decode!(res.body)
          |> Enum.map(fn %{"language" => language} -> language |> String.downcase() end)
          |> Enum.map(fn language ->
            if String.contains?(language, "-") do
              [language, language |> String.split("-") |> Enum.at(0)]
            else
              language
            end
          end)
          |> List.flatten()
          |> Enum.uniq()

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

  defp api_key do
    Pleroma.Config.get([__MODULE__, :api_key])
  end
end
