# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.BBS.Handler do
  use Sshd.ShellHandler
  alias Pleroma.Activity
  alias Pleroma.HTML
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI

  def on_shell(username, _pubkey, _ip, _port) do
    :ok = IO.puts("Welcome to #{Pleroma.Config.get([:instance, :name])}!")
    user = Pleroma.User.get_cached_by_nickname(to_string(username))
    Logger.debug("#{inspect(user)}")
    loop(run_state(user: user))
  end

  def on_connect(username, ip, port, method) do
    Logger.debug(fn ->
      """
      Incoming SSH shell #{inspect(self())} requested for #{username} from #{inspect(ip)}:#{inspect(port)} using #{inspect(method)}
      """
    end)
  end

  def on_disconnect(username, ip, port) do
    Logger.debug(fn ->
      "Disconnecting SSH shell for #{username} from #{inspect(ip)}:#{inspect(port)}"
    end)
  end

  defp loop(state) do
    self_pid = self()
    counter = state.counter
    prefix = state.prefix
    user = state.user

    input = spawn(fn -> io_get(self_pid, prefix, counter, user.nickname) end)
    wait_input(state, input)
  end

  def puts_activity(activity) do
    status = Pleroma.Web.MastodonAPI.StatusView.render("show.json", %{activity: activity})

    IO.puts("-- #{status.id} by #{status.account.display_name} (#{status.account.acct})")

    status.content
    |> String.split("<br/>")
    |> Enum.map(&HTML.strip_tags/1)
    |> Enum.map(&HtmlEntities.decode/1)
    |> Enum.map(&IO.puts/1)
  end

  def puts_notification(activity, user) do
    notification =
      Pleroma.Web.MastodonAPI.NotificationView.render("show.json", %{
        notification: activity,
        for: user
      })

    IO.puts(
      "== (#{notification.type}) #{notification.status.id} by #{notification.account.display_name} (#{notification.account.acct})"
    )

    notification.status.content
    |> String.split("<br/>")
    |> Enum.map(&HTML.strip_tags/1)
    |> Enum.map(&HtmlEntities.decode/1)
    |> (fn x ->
          case x do
            [content] ->
              "> " <> content

            [head | _tail] ->
              # "> " <> hd <> "..."
              head
              |> String.slice(1, 80)
              |> (fn x -> "> " <> x <> "..." end).()
          end
        end).()
    |> IO.puts()

    IO.puts("")
  end

  def handle_command(state, "help") do
    IO.puts("Available commands:")
    IO.puts("help - This help")
    IO.puts("home - Show the home timeline")
    IO.puts("p <text> - Post the given text")
    IO.puts("r <id> <text> - Reply to the post with the given id")
    IO.puts("t <id> - Show a thread from the given id")
    IO.puts("n - Show notifications")
    IO.puts("n read - Mark all notifactions as read")
    IO.puts("f <id> - Favourites the post with the given id")
    IO.puts("R <id> - Repeat the post with the given id")
    IO.puts("quit - Quit")

    state
  end

  def handle_command(%{user: user} = state, "r " <> text) do
    text = String.trim(text)
    [activity_id, rest] = String.split(text, " ", parts: 2)

    with %Activity{} <- Activity.get_by_id(activity_id),
         {:ok, _activity} <-
           CommonAPI.post(user, %{status: rest, in_reply_to_status_id: activity_id}) do
      IO.puts("Replied!")
    else
      _e -> IO.puts("Could not reply...")
    end

    state
  end

  def handle_command(%{user: user} = state, "t " <> activity_id) do
    with %Activity{} = activity <- Activity.get_by_id(activity_id) do
      activities =
        ActivityPub.fetch_activities_for_context(activity.data["context"], %{
          blocking_user: user,
          user: user,
          exclude_id: activity.id
        })

      case activities do
        [] ->
          activity_id
          |> Activity.get_by_id()
          |> puts_activity()

        _ ->
          activities
          |> Enum.reverse()
          |> Enum.each(&puts_activity/1)
      end
    else
      _e -> IO.puts("Could not show this thread...")
    end

    state
  end

  def handle_command(%{user: user} = state, "n read") do
    Pleroma.Notification.clear(user)
    IO.puts("All notifications were marked as read")

    state
  end

  def handle_command(%{user: user} = state, "n") do
    user
    |> Pleroma.Web.MastodonAPI.MastodonAPI.get_notifications(%{})
    |> Enum.each(&puts_notification(&1, user))

    state
  end

  def handle_command(%{user: user} = state, "p " <> text) do
    text = String.trim(text)

    with {:ok, activity} <- CommonAPI.post(user, %{status: text}) do
      IO.puts("Posted! ID: #{activity.id}")
    else
      _e -> IO.puts("Could not post...")
    end

    state
  end

  def handle_command(%{user: user} = state, "f " <> id) do
    id = String.trim(id)

    with %Activity{} = activity <- Activity.get_by_id(id),
         {:ok, _activity} <- CommonAPI.favorite(user, activity) do
      IO.puts("Favourited!")
    else
      _e -> IO.puts("Could not Favourite...")
    end

    state
  end

  def handle_command(state, "home") do
    user = state.user

    params =
      %{}
      |> Map.put(:type, ["Create"])
      |> Map.put(:blocking_user, user)
      |> Map.put(:muting_user, user)
      |> Map.put(:user, user)

    activities =
      [user.ap_id | Pleroma.User.following(user)]
      |> ActivityPub.fetch_activities(params)

    Enum.each(activities, fn activity ->
      puts_activity(activity)
    end)

    state
  end

  def handle_command(state, command) do
    IO.puts("Unknown command '#{command}'")
    state
  end

  defp wait_input(state, input) do
    receive do
      {:input, ^input, "quit\n"} ->
        IO.puts("Exiting...")

      {:input, ^input, code} when is_binary(code) ->
        code = String.trim(code)

        state = handle_command(state, code)

        loop(%{state | counter: state.counter + 1})

      {:input, ^input, {:error, :interrupted}} ->
        IO.puts("Caught Ctrl+C...")
        loop(%{state | counter: state.counter + 1})

      {:input, ^input, msg} ->
        :ok = Logger.warn("received unknown message: #{inspect(msg)}")
        loop(%{state | counter: state.counter + 1})
    end
  end

  defp run_state(opts) do
    %{prefix: "pleroma", counter: 1, user: opts[:user]}
  end

  defp io_get(pid, prefix, counter, username) do
    prompt = prompt(prefix, counter, username)
    send(pid, {:input, self(), IO.gets(:stdio, prompt)})
  end

  defp prompt(prefix, counter, username) do
    prompt = "#{username}@#{prefix}:#{counter}>"
    prompt <> " "
  end
end
