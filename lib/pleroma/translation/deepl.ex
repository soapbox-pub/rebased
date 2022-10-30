# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Translation.Deepl do
  import Pleroma.Web.Utils.Guards, only: [not_empty_string: 1]

  alias Pleroma.Translation.Service

  @behaviour Service

  @impl Service
  def configured? do
    not_empty_string(get_plan()) and not_empty_string(get_api_key())
  end

  @impl Service
  def translate(content, source_language, target_language) do
    endpoint = endpoint_url()

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

  defp endpoint_url do
    case get_plan() do
      :free -> "https://api-free.deepl.com/v2/translate"
      _ -> "https://api.deepl.com/v2/translate"
    end
  end

  defp get_plan do
    Pleroma.Config.get([__MODULE__, :plan])
  end

  defp get_api_key do
    Pleroma.Config.get([__MODULE__, :api_key])
  end
end
