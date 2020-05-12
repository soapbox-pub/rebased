# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.WebsocketHandler do
  require Logger

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.Streamer

  @behaviour :cowboy_websocket

  # Handled by periodic keepalive in Pleroma.Web.Streamer.Ping.
  @timeout :infinity

  def init(%{qs: qs} = req, state) do
    with params <- Enum.into(:cow_qs.parse_qs(qs), %{}),
         sec_websocket <- :cowboy_req.header("sec-websocket-protocol", req, nil),
         access_token <- Map.get(params, "access_token"),
         {:ok, user} <- authenticate_request(access_token, sec_websocket),
         {:ok, topic} <- Streamer.get_topic(Map.get(params, "stream"), user, params) do
      req =
        if sec_websocket do
          :cowboy_req.set_resp_header("sec-websocket-protocol", sec_websocket, req)
        else
          req
        end

      {:cowboy_websocket, req, %{user: user, topic: topic}, %{idle_timeout: @timeout}}
    else
      {:error, :bad_topic} ->
        Logger.debug("#{__MODULE__} bad topic #{inspect(req)}")
        {:ok, req} = :cowboy_req.reply(404, req)
        {:ok, req, state}

      {:error, :unauthorized} ->
        Logger.debug("#{__MODULE__} authentication error: #{inspect(req)}")
        {:ok, req} = :cowboy_req.reply(401, req)
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
  defp authenticate_request(nil, nil) do
    {:ok, nil}
  end

  # Authenticated streams.
  defp authenticate_request(access_token, sec_websocket) do
    token = access_token || sec_websocket

    with true <- is_bitstring(token),
         %Token{user_id: user_id} <- Repo.get_by(Token, token: token),
         user = %User{} <- User.get_cached_by_id(user_id) do
      {:ok, user}
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp streamer_socket(state) do
    %{transport_pid: self(), assigns: state}
  end
end
