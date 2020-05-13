# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Streamer do
  alias Pleroma.User
  alias Pleroma.Web.Streamer.State
  alias Pleroma.Web.Streamer.Worker

  @timeout 60_000
  @mix_env Mix.env()

  @public_streams ["public", "public:local", "public:media", "public:local:media"]
  @user_streams ["user", "user:notification", "direct"]

  @doc "Expands and authorizes a stream, and registers the process for streaming."
  @spec get_topic_and_add_socket(stream :: String.t(), State.t(), Map.t() | nil) ::
          {:ok, topic :: String.t()} | {:error, :bad_topic} | {:error, :unauthorized}
  def get_topic_and_add_socket(stream, socket, params \\ %{}) do
    user =
      case socket do
        %{assigns: %{user: user}} -> user
        _ -> nil
      end

    case get_topic(stream, user, params) do
      {:ok, topic} ->
        add_socket(topic, socket)
        {:ok, topic}

      error ->
        error
    end
  end

  @doc "Expand and authorizes a stream"
  @spec get_topic(stream :: String.t(), User.t() | nil, Map.t()) ::
          {:ok, topic :: String.t()} | {:error, :bad_topic}
  def get_topic(stream, user, params \\ %{})

  # Allow all public steams.
  def get_topic(stream, _, _) when stream in @public_streams do
    {:ok, stream}
  end

  # Allow all hashtags streams.
  def get_topic("hashtag", _, %{"tag" => tag}) do
    {:ok, "hashtag:" <> tag}
  end

  # Expand user streams.
  def get_topic(stream, %User{} = user, _) when stream in @user_streams do
    {:ok, stream <> ":" <> to_string(user.id)}
  end

  def get_topic(stream, _, _) when stream in @user_streams do
    {:error, :unauthorized}
  end

  # List streams.
  def get_topic("list", %User{} = user, %{"list" => id}) do
    if Pleroma.List.get(id, user) do
      {:ok, "list:" <> to_string(id)}
    else
      {:error, :bad_topic}
    end
  end

  def get_topic("list", _, _) do
    {:error, :unauthorized}
  end

  def get_topic(_, _, _) do
    {:error, :bad_topic}
  end

  def add_socket(topic, socket) do
    State.add_socket(topic, socket)
  end

  def remove_socket(topic, socket) do
    State.remove_socket(topic, socket)
  end

  def get_sockets do
    State.get_sockets()
  end

  def stream(topics, items) do
    if should_send?() do
      Task.async(fn ->
        :poolboy.transaction(
          :streamer_worker,
          &Worker.stream(&1, topics, items),
          @timeout
        )
      end)
    end
  end

  def supervisor, do: Pleroma.Web.Streamer.Supervisor

  defp should_send? do
    handle_should_send(@mix_env)
  end

  defp handle_should_send(:test) do
    case Process.whereis(:streamer_worker) do
      nil ->
        false

      pid ->
        Process.alive?(pid)
    end
  end

  defp handle_should_send(:benchmark), do: false

  defp handle_should_send(_), do: true
end
