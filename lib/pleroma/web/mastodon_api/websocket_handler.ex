# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.WebsocketHandler do
  require Logger

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.Streamer
  alias Pleroma.Web.StreamerView

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
         {:ok, user, oauth_token} <- authenticate_request(access_token, sec_websocket),
         {:ok, topic} <- Streamer.get_topic(params["stream"], user, oauth_token, params) do
      req =
        if sec_websocket do
          :cowboy_req.set_resp_header("sec-websocket-protocol", sec_websocket, req)
        else
          req
        end

      topics =
        if topic do
          [topic]
        else
          []
        end

      {:cowboy_websocket, req,
       %{user: user, topics: topics, oauth_token: oauth_token, count: 0, timer: nil},
       %{idle_timeout: @timeout}}
    else
      {:error, :bad_topic} ->
        Logger.debug("#{__MODULE__} bad topic #{inspect(req)}")
        req = :cowboy_req.reply(404, req)
        {:ok, req, state}

      {:error, :unauthorized} ->
        Logger.debug("#{__MODULE__} authentication error: #{inspect(req)}")
        req = :cowboy_req.reply(401, req)
        {:ok, req, state}
    end
  end

  def websocket_init(state) do
    Logger.debug(
      "#{__MODULE__} accepted websocket connection for user #{(state.user || %{id: "anonymous"}).id}, topics #{state.topics}"
    )

    Enum.each(state.topics, fn topic -> Streamer.add_socket(topic, state.oauth_token) end)
    {:ok, %{state | timer: timer()}}
  end

  # Client's Pong frame.
  def websocket_handle(:pong, state) do
    if state.timer, do: Process.cancel_timer(state.timer)
    {:ok, %{state | timer: timer()}}
  end

  # We only receive pings for now
  def websocket_handle(:ping, state), do: {:ok, state}

  def websocket_handle({:text, text}, state) do
    with {:ok, %{} = event} <- Jason.decode(text) do
      handle_client_event(event, state)
    else
      _ ->
        Logger.error("#{__MODULE__} received non-JSON event: #{inspect(text)}")
        {:ok, state}
    end
  end

  def websocket_handle(frame, state) do
    Logger.error("#{__MODULE__} received frame: #{inspect(frame)}")
    {:ok, state}
  end

  def websocket_info({:render_with_user, view, template, item, topic}, state) do
    user = %User{} = User.get_cached_by_ap_id(state.user.ap_id)

    unless Streamer.filtered_by_user?(user, item) do
      websocket_info({:text, view.render(template, item, user, topic)}, %{state | user: user})
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

  def websocket_info(:close, state) do
    {:stop, state}
  end

  # State can be `[]` only in case we terminate before switching to websocket,
  # we already log errors for these cases in `init/1`, so just do nothing here
  def terminate(_reason, _req, []), do: :ok

  def terminate(reason, _req, state) do
    Logger.debug(
      "#{__MODULE__} terminating websocket connection for user #{(state.user || %{id: "anonymous"}).id}, topics #{state.topics || "?"}: #{inspect(reason)}"
    )

    Enum.each(state.topics, fn topic -> Streamer.remove_socket(topic) end)
    :ok
  end

  # Public streams without authentication.
  defp authenticate_request(nil, nil) do
    {:ok, nil, nil}
  end

  # Authenticated streams.
  defp authenticate_request(access_token, sec_websocket) do
    token = access_token || sec_websocket

    with true <- is_bitstring(token),
         oauth_token = %Token{user_id: user_id} <- Repo.get_by(Token, token: token),
         user = %User{} <- User.get_cached_by_id(user_id) do
      {:ok, user, oauth_token}
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp timer do
    Process.send_after(self(), :tick, @tick)
  end

  defp handle_client_event(%{"type" => "subscribe", "stream" => _topic} = params, state) do
    with {_, {:ok, topic}} <-
           {:topic, Streamer.get_topic(params["stream"], state.user, state.oauth_token, params)},
         {_, false} <- {:subscribed, topic in state.topics} do
      Streamer.add_socket(topic, state.oauth_token)

      {[
         {:text,
          StreamerView.render("pleroma_respond.json", %{type: "subscribe", result: "success"})}
       ], %{state | topics: [topic | state.topics]}}
    else
      {:subscribed, true} ->
        {[
           {:text,
            StreamerView.render("pleroma_respond.json", %{type: "subscribe", result: "ignored"})}
         ], state}

      {:topic, {:error, error}} ->
        {[
           {:text,
            StreamerView.render("pleroma_respond.json", %{
              type: "subscribe",
              result: "error",
              error: error
            })}
         ], state}
    end
  end

  defp handle_client_event(%{"type" => "unsubscribe", "stream" => _topic} = params, state) do
    with {_, {:ok, topic}} <-
           {:topic, Streamer.get_topic(params["stream"], state.user, state.oauth_token, params)},
         {_, true} <- {:subscribed, topic in state.topics} do
      Streamer.remove_socket(topic)

      {[
         {:text,
          StreamerView.render("pleroma_respond.json", %{type: "unsubscribe", result: "success"})}
       ], %{state | topics: List.delete(state.topics, topic)}}
    else
      {:subscribed, false} ->
        {[
           {:text,
            StreamerView.render("pleroma_respond.json", %{type: "unsubscribe", result: "ignored"})}
         ], state}

      {:topic, {:error, error}} ->
        {[
           {:text,
            StreamerView.render("pleroma_respond.json", %{
              type: "unsubscribe",
              result: "error",
              error: error
            })}
         ], state}
    end
  end

  defp handle_client_event(
         %{"type" => "pleroma:authenticate", "token" => access_token} = _params,
         state
       ) do
    with {:auth, nil, nil} <- {:auth, state.user, state.oauth_token},
         {:ok, user, oauth_token} <- authenticate_request(access_token, nil) do
      {[
         {:text,
          StreamerView.render("pleroma_respond.json", %{
            type: "pleroma:authenticate",
            result: "success"
          })}
       ], %{state | user: user, oauth_token: oauth_token}}
    else
      {:auth, _, _} ->
        {[
           {:text,
            StreamerView.render("pleroma_respond.json", %{
              type: "pleroma:authenticate",
              result: "error",
              error: :already_authenticated
            })}
         ], state}

      _ ->
        {[
           {:text,
            StreamerView.render("pleroma_respond.json", %{
              type: "pleroma:authenticate",
              result: "error",
              error: :unauthorized
            })}
         ], state}
    end
  end

  defp handle_client_event(params, state) do
    Logger.error("#{__MODULE__} received unknown event: #{inspect(params)}")
    {[], state}
  end
end
