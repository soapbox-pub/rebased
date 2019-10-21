# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.WebsocketHandler do
  require Logger

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.Streamer

  @behaviour :cowboy_websocket

  @streams [
    "public",
    "public:local",
    "public:media",
    "public:local:media",
    "user",
    "user:notification",
    "direct",
    "list",
    "hashtag"
  ]
  @anonymous_streams ["public", "public:local", "hashtag"]

  # Handled by periodic keepalive in Pleroma.Web.Streamer.Ping.
  @timeout :infinity

  def init(%{qs: qs} = req, state) do
    with params <- :cow_qs.parse_qs(qs),
         sec_websocket <- :cowboy_req.header("sec-websocket-protocol", req, nil),
         access_token <- List.keyfind(params, "access_token", 0),
         {_, stream} <- List.keyfind(params, "stream", 0),
         {:ok, user} <- allow_request(stream, [access_token, sec_websocket]),
         topic when is_binary(topic) <- expand_topic(stream, params) do
      req =
        if sec_websocket do
          :cowboy_req.set_resp_header("sec-websocket-protocol", sec_websocket, req)
        else
          req
        end

      {:cowboy_websocket, req, %{user: user, topic: topic}, %{idle_timeout: @timeout}}
    else
      {:error, code} ->
        Logger.debug("#{__MODULE__} denied connection: #{inspect(code)} - #{inspect(req)}")
        {:ok, req} = :cowboy_req.reply(code, req)
        {:ok, req, state}

      error ->
        Logger.debug("#{__MODULE__} denied connection: #{inspect(error)} - #{inspect(req)}")
        {:ok, req} = :cowboy_req.reply(400, req)
        {:ok, req, state}
    end
  end

  def websocket_init(state) do
    send(self(), :subscribe)
    {:ok, state}
  end

  # We never receive messages.
  def websocket_handle(_frame, state) do
    {:ok, state}
  end

  def websocket_info(:subscribe, state) do
    Logger.debug(
      "#{__MODULE__} accepted websocket connection for user #{
        (state.user || %{id: "anonymous"}).id
      }, topic #{state.topic}"
    )

    Streamer.add_socket(state.topic, streamer_socket(state))
    {:ok, state}
  end

  def websocket_info({:text, message}, state) do
    {:reply, {:text, message}, state}
  end

  def terminate(reason, _req, state) do
    Logger.debug(
      "#{__MODULE__} terminating websocket connection for user #{
        (state.user || %{id: "anonymous"}).id
      }, topic #{state.topic || "?"}: #{inspect(reason)}"
    )

    Streamer.remove_socket(state.topic, streamer_socket(state))
    :ok
  end

  # Public streams without authentication.
  defp allow_request(stream, [nil, nil]) when stream in @anonymous_streams do
    {:ok, nil}
  end

  # Authenticated streams.
  defp allow_request(stream, [access_token, sec_websocket]) when stream in @streams do
    token =
      with {"access_token", token} <- access_token do
        token
      else
        _ -> sec_websocket
      end

    with true <- is_bitstring(token),
         %Token{user_id: user_id} <- Repo.get_by(Token, token: token),
         user = %User{} <- User.get_cached_by_id(user_id) do
      {:ok, user}
    else
      _ -> {:error, 403}
    end
  end

  # Not authenticated.
  defp allow_request(stream, _) when stream in @streams, do: {:error, 403}

  # No matching stream.
  defp allow_request(_, _), do: {:error, 404}

  defp expand_topic("hashtag", params) do
    case List.keyfind(params, "tag", 0) do
      {_, tag} -> "hashtag:#{tag}"
      _ -> nil
    end
  end

  defp expand_topic("list", params) do
    case List.keyfind(params, "list", 0) do
      {_, list} -> "list:#{list}"
      _ -> nil
    end
  end

  defp expand_topic(topic, _), do: topic

  defp streamer_socket(state) do
    %{transport_pid: self(), assigns: state}
  end
end
