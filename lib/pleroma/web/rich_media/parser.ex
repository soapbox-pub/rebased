# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parser do
  require Logger

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

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
      with {:ok, data} <- get_cached_or_parse(url),
           {:ok, _} <- set_ttl_based_on_image(data, url) do
        {:ok, data}
      end
    end

    defp get_cached_or_parse(url) do
      case @cachex.fetch(:rich_media_cache, url, fn ->
             case parse_url(url) do
               {:ok, _} = res ->
                 {:commit, res}

               {:error, reason} = e ->
                 # Unfortunately we have to log errors here, instead of doing that
                 # along with ttl setting at the bottom. Otherwise we can get log spam
                 # if more than one process was waiting for the rich media card
                 # while it was generated. Ideally we would set ttl here as well,
                 # so we don't override it number_of_waiters_on_generation
                 # times, but one, obviously, can't set ttl for not-yet-created entry
                 # and Cachex doesn't support returning ttl from the fetch callback.
                 log_error(url, reason)
                 {:commit, e}
             end
           end) do
        {action, res} when action in [:commit, :ok] ->
          case res do
            {:ok, _data} = res ->
              res

            {:error, reason} = e ->
              if action == :commit, do: set_error_ttl(url, reason)
              e
          end

        {:error, e} ->
          {:error, {:cachex_error, e}}
      end
    end

    defp set_error_ttl(_url, :body_too_large), do: :ok
    defp set_error_ttl(_url, {:content_type, _}), do: :ok

    # The TTL is not set for the errors above, since they are unlikely to change
    # with time

    defp set_error_ttl(url, _reason) do
      ttl = Pleroma.Config.get([:rich_media, :failure_backoff], 60_000)
      @cachex.expire(:rich_media_cache, url, ttl)
      :ok
    end

    defp log_error(url, {:invalid_metadata, data}) do
      Logger.debug(fn -> "Incomplete or invalid metadata for #{url}: #{inspect(data)}" end)
    end

    defp log_error(url, reason) do
      Logger.warn(fn -> "Rich media error for #{url}: #{inspect(reason)}" end)
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
  @spec set_ttl_based_on_image(map(), String.t()) ::
          {:ok, Integer.t() | :noop} | {:error, :no_key}
  def set_ttl_based_on_image(data, url) do
    case get_ttl_from_image(data, url) do
      {:ok, ttl} when is_number(ttl) ->
        ttl = ttl * 1000

        case @cachex.expire_at(:rich_media_cache, url, ttl) do
          {:ok, true} -> {:ok, ttl}
          {:ok, false} -> {:error, :no_key}
        end

      _ ->
        {:ok, :noop}
    end
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

  def parse_url(url) do
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
    {:error, {:invalid_metadata, data}}
  end

  defp clean_parsed_data(data) do
    data
    |> Enum.reject(fn {key, val} ->
      not match?({:ok, _}, Jason.encode(%{key => val}))
    end)
    |> Map.new()
  end
end
