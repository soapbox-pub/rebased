# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Language.Translation do
  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

  def configured? do
    provider = get_provider()

    !!provider and provider.configured?
  end

  def missing_dependencies do
    provider = get_provider()

    if provider do
      provider.missing_dependencies()
    else
      []
    end
  end

  def translate(text, source_language, target_language) do
    cache_key = get_cache_key(text, source_language, target_language)

    case @cachex.get(:translations_cache, cache_key) do
      {:ok, nil} ->
        provider = get_provider()

        result =
          if !configured?() do
            {:error, :not_found}
          else
            provider.translate(text, source_language, target_language)
          end

        store_result(result, cache_key)

        result

      {:ok, result} ->
        {:ok, result}

      {:error, error} ->
        {:error, error}
    end
  end

  def supported_languages(type) when type in [:source, :target] do
    provider = get_provider()

    cache_key = "#{type}_languages/#{provider.name()}"

    case @cachex.get(:translations_cache, cache_key) do
      {:ok, nil} ->
        result =
          if !configured?() do
            {:error, :not_found}
          else
            provider.supported_languages(type)
          end

        store_result(result, cache_key)

        result

      {:ok, result} ->
        {:ok, result}

      {:error, error} ->
        {:error, error}
    end
  end

  def languages_matrix do
    provider = get_provider()

    cache_key = "languages_matrix/#{provider.name()}"

    case @cachex.get(:translations_cache, cache_key) do
      {:ok, nil} ->
        result =
          if !configured?() do
            {:error, :not_found}
          else
            provider.languages_matrix()
          end

        store_result(result, cache_key)

        result

      {:ok, result} ->
        {:ok, result}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_provider, do: Pleroma.Config.get([__MODULE__, :provider])

  defp get_cache_key(text, source_language, target_language) do
    "#{source_language}/#{target_language}/#{content_hash(text)}"
  end

  defp store_result({:ok, result}, cache_key) do
    @cachex.put(:translations_cache, cache_key, result)
  end

  defp store_result(_, _), do: nil

  defp content_hash(text), do: :crypto.hash(:sha256, text) |> Base.encode64()
end
