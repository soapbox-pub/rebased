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

  @behaviour Phoenix.Socket.Transport

  # Client ping period.
  @tick :timer.seconds(30)

  @impl Phoenix.Socket.Transport
  def child_spec(_opts), do: :ignore

  # This only prepares the connection and is not in the process yet
  @impl Phoenix.Socket.Transport
  def connect(%{params: params} = transport_info) do
    with access_token <- find_access_token(transport_info),
         {:ok, user, oauth_token} <- authenticate_request(access_token),
         {:ok, topic} <-
           Streamer.get_topic(params["stream"], user, oauth_token, params) do
      topics =
        if topic do
          [topic]
        else
          []
        end

      state = %{
        user: user,
        topics: topics,
        oauth_token: oauth_token,
        count: 0,
        timer: nil
      }

      {:ok, state}
    else
      {:error, :bad_topic} ->
        Logger.debug("#{__MODULE__} bad topic #{inspect(transport_info)}")

        {:error, :bad_topic}

      {:error, :unauthorized} ->
        Logger.debug("#{__MODULE__} authentication error: #{inspect(transport_info)}")
        {:error, :unauthorized}
    end
  end

  # All subscriptions/links and messages cannot be created
  # until the processed is launched with init/1
  @impl Phoenix.Socket.Transport
  def init(state) do
    Enum.each(state.topics, fn topic -> Streamer.add_socket(topic, state.oauth_token) end)

    Process.send_after(self(), :ping, @tick)

    {:ok, state}
  end

  @impl Phoenix.Socket.Transport
  def handle_in({text, [opcode: :text]}, state) do
    with {:ok, %{} = event} <- Jason.decode(text) do
      handle_client_event(event, state)
    else
      _ ->
        Logger.error("#{__MODULE__} received non-JSON event: #{inspect(text)}")
        {:ok, state}
    end
  end

  def handle_in(frame, state) do
    Logger.error("#{__MODULE__} received frame: #{inspect(frame)}")
    {:ok, state}
  end

  @impl Phoenix.Socket.Transport
  def handle_info({:render_with_user, view, template, item, topic}, state) do
    user = %User{} = User.get_cached_by_ap_id(state.user.ap_id)

    unless Streamer.filtered_by_user?(user, item) do
      message = view.render(template, item, user, topic)
      {:push, {:text, message}, %{state | user: user}}
    else
      {:ok, state}
    end
  end

  def handle_info({:text, text}, state) do
    {:push, {:text, text}, state}
  end

  def handle_info(:ping, state) do
    Process.send_after(self(), :ping, @tick)

    {:push, {:ping, ""}, state}
  end

  def handle_info(:close, state) do
    {:stop, {:closed, ~c"connection closed by server"}, state}
  end

  def handle_info(msg, state) do
    Logger.debug("#{__MODULE__} received info: #{inspect(msg)}")

    {:ok, state}
  end

  @impl Phoenix.Socket.Transport
  def terminate(reason, state) do
    Logger.debug(
      "#{__MODULE__} terminating websocket connection for user #{(state.user || %{id: "anonymous"}).id}, topics #{state.topics || "?"}: #{inspect(reason)})"
    )

    Enum.each(state.topics, fn topic -> Streamer.remove_socket(topic) end)
    :ok
  end

  # Public streams without authentication.
  defp authenticate_request(nil) do
    {:ok, nil, nil}
  end

  # Authenticated streams.
  defp authenticate_request(access_token) do
    with oauth_token = %Token{user_id: user_id} <- Repo.get_by(Token, token: access_token),
         user = %User{} <- User.get_cached_by_id(user_id) do
      {:ok, user, oauth_token}
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp handle_client_event(%{"type" => "subscribe", "stream" => _topic} = params, state) do
    with {_, {:ok, topic}} <-
           {:topic, Streamer.get_topic(params["stream"], state.user, state.oauth_token, params)},
         {_, false} <- {:subscribed, topic in state.topics} do
      Streamer.add_socket(topic, state.oauth_token)

      message =
        StreamerView.render("pleroma_respond.json", %{type: "subscribe", result: "success"})

      {:reply, :ok, {:text, message}, %{state | topics: [topic | state.topics]}}
    else
      {:subscribed, true} ->
        message =
          StreamerView.render("pleroma_respond.json", %{type: "subscribe", result: "ignored"})

        {:reply, :error, {:text, message}, state}

      {:topic, {:error, error}} ->
        message =
          StreamerView.render("pleroma_respond.json", %{
            type: "subscribe",
            result: "error",
            error: error
          })

        {:reply, :error, {:text, message}, state}
    end
  end

  defp handle_client_event(%{"type" => "unsubscribe", "stream" => _topic} = params, state) do
    with {_, {:ok, topic}} <-
           {:topic, Streamer.get_topic(params["stream"], state.user, state.oauth_token, params)},
         {_, true} <- {:subscribed, topic in state.topics} do
      Streamer.remove_socket(topic)

      message =
        StreamerView.render("pleroma_respond.json", %{type: "unsubscribe", result: "success"})

      {:reply, :ok, {:text, message}, %{state | topics: List.delete(state.topics, topic)}}
    else
      {:subscribed, false} ->
        message =
          StreamerView.render("pleroma_respond.json", %{type: "unsubscribe", result: "ignored"})

        {:reply, :error, {:text, message}, state}

      {:topic, {:error, error}} ->
        message =
          StreamerView.render("pleroma_respond.json", %{
            type: "unsubscribe",
            result: "error",
            error: error
          })

        {:reply, :error, {:text, message}, state}
    end
  end

  defp handle_client_event(
         %{"type" => "pleroma:authenticate", "token" => access_token} = _params,
         state
       ) do
    with {:auth, nil, nil} <- {:auth, state.user, state.oauth_token},
         {:ok, user, oauth_token} <- authenticate_request(access_token) do
      message =
        StreamerView.render("pleroma_respond.json", %{
          type: "pleroma:authenticate",
          result: "success"
        })

      {:reply, :ok, {:text, message}, %{state | user: user, oauth_token: oauth_token}}
    else
      {:auth, _, _} ->
        message =
          StreamerView.render("pleroma_respond.json", %{
            type: "pleroma:authenticate",
            result: "error",
            error: :already_authenticated
          })

        {:reply, :error, {:text, message}, state}

      _ ->
        message =
          StreamerView.render("pleroma_respond.json", %{
            type: "pleroma:authenticate",
            result: "error",
            error: :unauthorized
          })

        {:reply, :error, {:text, message}, state}
    end
  end

  defp handle_client_event(params, state) do
    Logger.error("#{__MODULE__} received unknown event: #{inspect(params)}")
    {:ok, state}
  end

  def handle_error(conn, :unauthorized) do
    Plug.Conn.send_resp(conn, 401, "Unauthorized")
  end

  def handle_error(conn, _reason) do
    Plug.Conn.send_resp(conn, 404, "Not Found")
  end

  defp find_access_token(%{
         connect_info: %{sec_websocket_protocol: [token]}
       }),
       do: token

  defp find_access_token(%{params: %{"access_token" => token}}), do: token

  defp find_access_token(_), do: nil
end
