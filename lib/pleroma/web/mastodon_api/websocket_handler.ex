# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.WebsocketHandler do
  require Logger

  alias Pleroma.Web.OAuth.Token
  alias Pleroma.{User, Repo}

  @behaviour :cowboy_websocket_handler

  @streams [
    "public",
    "public:local",
    "public:media",
    "public:local:media",
    "user",
    "direct",
    "list",
    "hashtag"
  ]
  @anonymous_streams ["public", "public:local", "hashtag"]

  # Handled by periodic keepalive in Pleroma.Web.Streamer.
  @timeout :infinity

  def init(_type, _req, _opts) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  def websocket_init(_type, req, _opts) do
    with {qs, req} <- :cowboy_req.qs(req),
         params <- :cow_qs.parse_qs(qs),
         access_token <- List.keyfind(params, "access_token", 0),
         {_, stream} <- List.keyfind(params, "stream", 0),
         {:ok, user} <- allow_request(stream, access_token),
         topic when is_binary(topic) <- expand_topic(stream, params) do
      send(self(), :subscribe)
      {:ok, req, %{user: user, topic: topic}, @timeout}
    else
      {:error, code} ->
        Logger.debug("#{__MODULE__} denied connection: #{inspect(code)} - #{inspect(req)}")
        {:ok, req} = :cowboy_req.reply(code, req)
        {:shutdown, req}

      error ->
        Logger.debug("#{__MODULE__} denied connection: #{inspect(error)} - #{inspect(req)}")
        {:shutdown, req}
    end
  end

  # We never receive messages.
  def websocket_handle(_frame, req, state) do
    {:ok, req, state}
  end

  def websocket_info(:subscribe, req, state) do
    Logger.debug(
      "#{__MODULE__} accepted websocket connection for user #{
        (state.user || %{id: "anonymous"}).id
      }, topic #{state.topic}"
    )

    Pleroma.Web.Streamer.add_socket(state.topic, streamer_socket(state))
    {:ok, req, state}
  end

  def websocket_info({:text, message}, req, state) do
    {:reply, {:text, message}, req, state}
  end

  def websocket_terminate(reason, _req, state) do
    Logger.debug(
      "#{__MODULE__} terminating websocket connection for user #{
        (state.user || %{id: "anonymous"}).id
      }, topic #{state.topic || "?"}: #{inspect(reason)}"
    )

    Pleroma.Web.Streamer.remove_socket(state.topic, streamer_socket(state))
    :ok
  end

  # Public streams without authentication.
  defp allow_request(stream, nil) when stream in @anonymous_streams do
    {:ok, nil}
  end

  # Authenticated streams.
  defp allow_request(stream, {"access_token", access_token}) when stream in @streams do
    with %Token{user_id: user_id} <- Repo.get_by(Token, token: access_token),
         user = %User{} <- Repo.get(User, user_id) do
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
