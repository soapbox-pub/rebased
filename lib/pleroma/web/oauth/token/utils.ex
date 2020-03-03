# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.Token.Utils do
  @moduledoc """
  Auxiliary functions for dealing with tokens.
  """

  alias Pleroma.Repo
  alias Pleroma.Web.OAuth.App

  @doc "Fetch app by client credentials from request"
  @spec fetch_app(Plug.Conn.t()) :: {:ok, App.t()} | {:error, :not_found}
  def fetch_app(conn) do
    res =
      conn
      |> fetch_client_credentials()
      |> fetch_client

    case res do
      %App{} = app -> {:ok, app}
      _ -> {:error, :not_found}
    end
  end

  defp fetch_client({id, secret}) when is_binary(id) and is_binary(secret) do
    Repo.get_by(App, client_id: id, client_secret: secret)
  end

  defp fetch_client({_id, _secret}), do: nil

  defp fetch_client_credentials(conn) do
    # Per RFC 6749, HTTP Basic is preferred to body params
    with ["Basic " <> encoded] <- Plug.Conn.get_req_header(conn, "authorization"),
         {:ok, decoded} <- Base.decode64(encoded),
         [id, secret] <-
           Enum.map(
             String.split(decoded, ":"),
             fn s -> URI.decode_www_form(s) end
           ) do
      {id, secret}
    else
      _ -> {conn.params["client_id"], conn.params["client_secret"]}
    end
  end

  @doc "convert token inserted_at to unix timestamp"
  def format_created_at(%{inserted_at: inserted_at} = _token) do
    inserted_at
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix()
  end

  @doc false
  @spec generate_token(keyword()) :: binary()
  def generate_token(opts \\ []) do
    opts
    |> Keyword.get(:size, 32)
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  # XXX - for whatever reason our token arrives urlencoded, but Plug.Conn should be
  # decoding it.  Investigate sometime.
  def fix_padding(token) do
    token
    |> URI.decode()
    |> Base.url_decode64!(padding: false)
    |> Base.url_encode64(padding: false)
  end
end
