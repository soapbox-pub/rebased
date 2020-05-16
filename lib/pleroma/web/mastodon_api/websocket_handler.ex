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

  # Client ping period.
  @tick :timer.seconds(30)
  # Cowboy timeout period.
  @timeout :timer.seconds(60)
  # Hibernate every X messages
  @hibernate_every 100

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

      {:cowboy_websocket, req, %{user: user, topic: topic, count: 0, timer: nil},
       %{idle_timeout: @timeout}}
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
    Logger.debug(
      "#{__MODULE__} accepted websocket connection for user #{
        (state.user || %{id: "anonymous"}).id
      }, topic #{state.topic}"
    )

    Streamer.add_socket(state.topic, state.user)
    {:ok, %{state | timer: timer()}}
  end

  # Client's Pong frame.
  def websocket_handle(:pong, state) do
    if state.timer, do: Process.cancel_timer(state.timer)
    {:ok, %{state | timer: timer()}}
  end

  # We never receive messages.
  def websocket_handle(frame, state) do
    Logger.error("#{__MODULE__} received frame: #{inspect(frame)}")
    {:ok, state}
  end

  def websocket_info({:render_with_user, view, template, item}, state) do
    user = %User{} = User.get_cached_by_ap_id(state.user.ap_id)

    unless Streamer.filtered_by_user?(user, item) do
      websocket_info({:text, view.render(template, item, user)}, %{state | user: user})
    else
      {:ok, state}
    end
  end

  def websocket_info({:text, message}, state) do
    # If the websocket processed X messages, force an hibernate/GC.
    # We don't hibernate at every message to balance CPU usage/latency with RAM usage.
    if state.count > @hibernate_every do
      {:reply, {:text, message}, %{state | count: 0}, :hibernate}
    else
      {:reply, {:text, message}, %{state | count: state.count + 1}}
    end
  end

  # Ping tick. We don't re-queue a timer there, it is instead queued when :pong is received.
  # As we hibernate there, reset the count to 0.
  # If the client misses :pong, Cowboy will automatically timeout the connection after
  # `@idle_timeout`.
  def websocket_info(:tick, state) do
    {:reply, :ping, %{state | timer: nil, count: 0}, :hibernate}
  end

  def terminate(reason, _req, state) do
    Logger.debug(
      "#{__MODULE__} terminating websocket connection for user #{
        (state.user || %{id: "anonymous"}).id
      }, topic #{state.topic || "?"}: #{inspect(reason)}"
    )

    Streamer.remove_socket(state.topic)
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

  defp timer do
    Process.send_after(self(), :tick, @tick)
  end
end
