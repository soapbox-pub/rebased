# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Language.Translation.Libretranslate do
  import Pleroma.Web.Utils.Guards, only: [not_empty_string: 1]

  alias Pleroma.Language.Translation.Provider

  use Provider

  @behaviour Provider

  @name "LibreTranslate"

  @impl Provider
  def configured?, do: not_empty_string(base_url()) and not_empty_string(api_key())

  @impl Provider
  def translate(content, source_language, target_language) do
    case Pleroma.HTTP.post(
           base_url() <> "/translate",
           Jason.encode!(%{
             q: content,
             source: source_language |> String.upcase(),
             target: target_language,
             format: "html",
             api_key: api_key()
           }),
           [
             {"Content-Type", "application/json"}
           ]
         ) do
      {:ok, %{status: 429}} ->
        {:error, :too_many_requests}

      {:ok, %{status: 403}} ->
        {:error, :quota_exceeded}

      {:ok, %{status: 200} = res} ->
        %{
          "translatedText" => content
        } = Jason.decode!(res.body)

        {:ok,
         %{
           content: content,
           detected_source_language: source_language,
           provider: "LibreTranslate"
         }}

      _ ->
        {:error, :internal_server_error}
    end
  end

  @impl Provider
  def supported_languages(_) do
    case Pleroma.HTTP.get(base_url() <> "/languages") do
      {:ok, %{status: 200} = res} ->
        languages =
          Jason.decode!(res.body)
          |> Enum.map(fn %{"code" => code} -> code end)

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
    Pleroma.Config.get([__MODULE__, :api_key], "")
  end
end
