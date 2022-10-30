# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Translation.Libretranslate do
  import Pleroma.Web.Utils.Guards, only: [not_empty_string: 1]

  alias Pleroma.Translation.Service

  @behaviour Service

  @impl Service
  def configured?, do: not_empty_string(get_base_url())

  @impl Service
  def translate(content, source_language, target_language) do
    endpoint = endpoint_url()

    case Pleroma.HTTP.post(
           endpoint,
           Jason.encode!(%{
             q: content,
             source: source_language |> String.upcase(),
             target: target_language,
             format: "html",
             api_key: get_api_key()
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

  defp endpoint_url do
    get_base_url() <> "/translate"
  end

  defp get_base_url do
    Pleroma.Config.get([__MODULE__, :base_url])
  end

  defp get_api_key do
    Pleroma.Config.get([__MODULE__, :api_key], "")
  end
end
