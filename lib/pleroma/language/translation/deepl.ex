# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Language.Translation.Deepl do
  import Pleroma.Web.Utils.Guards, only: [not_empty_string: 1]

  alias Pleroma.Language.Translation.Provider

  @behaviour Provider

  @impl Provider
  def configured? do
    not_empty_string(get_base_url()) and not_empty_string(get_api_key())
  end

  @impl Provider
  def translate(content, source_language, target_language) do
    endpoint = get_endpoint()

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
             {"Authorization", "DeepL-Auth-Key #{get_api_key()}"}
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
           provider: "DeepL"
         }}

      _ ->
        {:error, :internal_server_error}
    end
  end

  defp get_endpoint do
    get_base_url()
    |> URI.merge("/v2/translate")
    |> URI.to_string()
  end

  defp get_base_url do
    Pleroma.Config.get([__MODULE__, :base_url])
  end

  defp get_api_key do
    Pleroma.Config.get([__MODULE__, :api_key])
  end
end
