# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parser do
  @hackney_options [
    pool: :media,
    recv_timeout: 2_000,
    max_body: 2_000_000,
    with_body: true
  ]

  defp parsers do
    Pleroma.Config.get([:rich_media, :parsers])
  end

  def parse(nil), do: {:error, "No URL provided"}

  if Pleroma.Config.get(:env) == :test do
    def parse(url), do: parse_url(url)
  else
    def parse(url) do
      try do
        Cachex.fetch!(:rich_media_cache, url, fn _ ->
          {:commit, parse_url(url)}
        end)
        |> set_ttl_based_on_image(url)
      rescue
        e ->
          {:error, "Cachex error: #{inspect(e)}"}
      end
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
  def set_ttl_based_on_image({:ok, data}, url) do
    with {:ok, nil} <- Cachex.ttl(:rich_media_cache, url),
         ttl when is_number(ttl) <- get_ttl_from_image(data, url) do
      Cachex.expire_at(:rich_media_cache, url, ttl * 1000)
      {:ok, data}
    else
      _ ->
        {:ok, data}
    end
  end

  defp get_ttl_from_image(data, url) do
    Pleroma.Config.get([:rich_media, :ttl_setters])
    |> Enum.reduce({:ok, nil}, fn
      module, {:ok, _ttl} ->
        module.ttl(data, url)

      _, error ->
        error
    end)
  end

  defp parse_url(url) do
    try do
      {:ok, %Tesla.Env{body: html}} = Pleroma.HTTP.get(url, [], adapter: @hackney_options)

      html
      |> parse_html()
      |> maybe_parse()
      |> Map.put(:url, url)
      |> clean_parsed_data()
      |> check_parsed_data()
    rescue
      e ->
        {:error, "Parsing error: #{inspect(e)} #{inspect(__STACKTRACE__)}"}
    end
  end

  defp parse_html(html), do: Floki.parse_document!(html)

  defp maybe_parse(html) do
    Enum.reduce_while(parsers(), %{}, fn parser, acc ->
      case parser.parse(html, acc) do
        {:ok, data} -> {:halt, data}
        {:error, _msg} -> {:cont, acc}
      end
    end)
  end

  defp check_parsed_data(%{title: title} = data)
       when is_binary(title) and byte_size(title) > 0 do
    {:ok, data}
  end

  defp check_parsed_data(data) do
    {:error, "Found metadata was invalid or incomplete: #{inspect(data)}"}
  end

  defp clean_parsed_data(data) do
    data
    |> Enum.reject(fn {key, val} ->
      with {:ok, _} <- Jason.encode(%{key => val}) do
        false
      else
        _ -> true
      end
    end)
    |> Map.new()
  end
end
