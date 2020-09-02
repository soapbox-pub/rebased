# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parser do
  require Logger

  defp parsers do
    Pleroma.Config.get([:rich_media, :parsers])
  end

  def parse(nil), do: {:error, "No URL provided"}

  if Pleroma.Config.get(:env) == :test do
    @spec parse(String.t()) :: {:ok, map()} | {:error, any()}
    def parse(url), do: parse_url(url)
  else
    @spec parse(String.t()) :: {:ok, map()} | {:error, any()}
    def parse(url) do
      Cachex.fetch!(:rich_media_cache, url, fn _ ->
        with {:ok, data} <- parse_url(url) do
          {:commit, {:ok, data}}
        else
          error -> {:ignore, error}
        end
      end)
      |> set_ttl_based_on_image(url)
    end
  end

  @doc """
  Set the rich media cache based on the expiration time of image.

  Adopt behaviour `Pleroma.Web.RichMedia.Parser.TTL`

  ## Example

      defmodule MyModule do
        @behaviour Pleroma.Web.RichMedia.Parser.TTL
        def ttl(data, url) do
          image_url = Map.get(data, :image)
          # do some parsing in the url and get the ttl of the image
          # and return ttl is unix time
          parse_ttl_from_url(image_url)
        end
      end

  Define the module in the config

      config :pleroma, :rich_media,
        ttl_setters: [MyModule]
  """
  @spec set_ttl_based_on_image({:ok, map()} | {:error, any()}, String.t()) ::
          {:ok, map()} | {:error, any()}
  def set_ttl_based_on_image({:ok, data}, url) do
    with {:ok, nil} <- Cachex.ttl(:rich_media_cache, url),
         {:ok, ttl} when is_number(ttl) <- get_ttl_from_image(data, url) do
      Cachex.expire_at(:rich_media_cache, url, ttl * 1000)
      {:ok, data}
    else
      _ ->
        {:ok, data}
    end
  end

  def set_ttl_based_on_image({:error, _} = error, _) do
    Logger.error("parsing error: #{inspect(error)}")
    error
  end

  defp get_ttl_from_image(data, url) do
    [:rich_media, :ttl_setters]
    |> Pleroma.Config.get()
    |> Enum.reduce({:ok, nil}, fn
      module, {:ok, _ttl} ->
        module.ttl(data, url)

      _, error ->
        error
    end)
  end

  defp parse_url(url) do
    with {:ok, %Tesla.Env{body: html}} <- Pleroma.Web.RichMedia.Helpers.rich_media_get(url),
         {:ok, html} <- Floki.parse_document(html) do
      html
      |> maybe_parse()
      |> Map.put("url", url)
      |> clean_parsed_data()
      |> check_parsed_data()
    end
  end

  defp maybe_parse(html) do
    Enum.reduce_while(parsers(), %{}, fn parser, acc ->
      case parser.parse(html, acc) do
        data when data != %{} -> {:halt, data}
        _ -> {:cont, acc}
      end
    end)
  end

  defp check_parsed_data(%{"title" => title} = data)
       when is_binary(title) and title != "" do
    {:ok, data}
  end

  defp check_parsed_data(data) do
    {:error, "Found metadata was invalid or incomplete: #{inspect(data)}"}
  end

  defp clean_parsed_data(data) do
    data
    |> Enum.reject(fn {key, val} ->
      not match?({:ok, _}, Jason.encode(%{key => val}))
    end)
    |> Map.new()
  end
end
