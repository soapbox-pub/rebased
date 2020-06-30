# Pleroma: A lightweight social networking server
# Copyright © 2015-2020 Tymon Tobolski <https://github.com/teamon/tesla/blob/master/lib/tesla/middleware/follow_redirects.ex>
# Copyright © 2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.Middleware.FollowRedirects do
  @moduledoc """
  Pool-aware version of https://github.com/teamon/tesla/blob/master/lib/tesla/middleware/follow_redirects.ex

  Follow 3xx redirects
  ## Options
  - `:max_redirects` - limit number of redirects (default: `5`)
  """

  alias Pleroma.Gun.ConnectionPool

  @behaviour Tesla.Middleware

  @max_redirects 5
  @redirect_statuses [301, 302, 303, 307, 308]

  @impl Tesla.Middleware
  def call(env, next, opts \\ []) do
    max = Keyword.get(opts, :max_redirects, @max_redirects)

    redirect(env, next, max)
  end

  defp redirect(env, next, left) do
    opts = env.opts[:adapter]

    case Tesla.run(env, next) do
      {:ok, %{status: status} = res} when status in @redirect_statuses and left > 0 ->
        release_conn(opts)

        case Tesla.get_header(res, "location") do
          nil ->
            {:ok, res}

          location ->
            location = parse_location(location, res)

            case get_conn(location, opts) do
              {:ok, opts} ->
                %{env | opts: Keyword.put(env.opts, :adapter, opts)}
                |> new_request(res.status, location)
                |> redirect(next, left - 1)

              e ->
                e
            end
        end

      {:ok, %{status: status}} when status in @redirect_statuses ->
        release_conn(opts)
        {:error, {__MODULE__, :too_many_redirects}}

      {:error, _} = e ->
        release_conn(opts)
        e

      other ->
        unless opts[:body_as] == :chunks do
          release_conn(opts)
        end

        other
    end
  end

  defp get_conn(location, opts) do
    uri = URI.parse(location)

    case ConnectionPool.get_conn(uri, opts) do
      {:ok, conn} ->
        {:ok, Keyword.merge(opts, conn: conn)}

      e ->
        e
    end
  end

  defp release_conn(opts) do
    ConnectionPool.release_conn(opts[:conn])
  end

  # The 303 (See Other) redirect was added in HTTP/1.1 to indicate that the originally
  # requested resource is not available, however a related resource (or another redirect)
  # available via GET is available at the specified location.
  # https://tools.ietf.org/html/rfc7231#section-6.4.4
  defp new_request(env, 303, location), do: %{env | url: location, method: :get, query: []}

  # The 307 (Temporary Redirect) status code indicates that the target
  # resource resides temporarily under a different URI and the user agent
  # MUST NOT change the request method (...)
  # https://tools.ietf.org/html/rfc7231#section-6.4.7
  defp new_request(env, 307, location), do: %{env | url: location}

  defp new_request(env, _, location), do: %{env | url: location, query: []}

  defp parse_location("https://" <> _rest = location, _env), do: location
  defp parse_location("http://" <> _rest = location, _env), do: location

  defp parse_location(location, env) do
    env.url
    |> URI.parse()
    |> URI.merge(location)
    |> URI.to_string()
  end
end
