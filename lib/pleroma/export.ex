# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Export do
  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.UserView

  import Ecto.Query

  @files ['actor.json', 'outbox.json', 'likes.json', 'bookmarks.json']

  def run(user) do
    with {:ok, path} <- create_dir(user),
         :ok <- actor(path, user),
         :ok <- statuses(path, user),
         :ok <- likes(path, user),
         :ok <- bookmarks(path, user),
         {:ok, zip_path} <- :zip.create('#{path}.zip', @files, cwd: path),
         {:ok, _} <- File.rm_rf(path) do
      {:ok, zip_path}
    end
  end

  def actor(dir, user) do
    with {:ok, json} <-
           UserView.render("user.json", %{user: user})
           |> Map.merge(%{"likes" => "likes.json", "bookmarks" => "bookmarks.json"})
           |> Jason.encode() do
      File.write(dir <> "/actor.json", json)
    end
  end

  defp create_dir(user) do
    datetime = Calendar.NaiveDateTime.Format.iso8601_basic(NaiveDateTime.utc_now())
    dir = Path.join(System.tmp_dir!(), "archive-#{user.id}-#{datetime}")

    with :ok <- File.mkdir(dir), do: {:ok, dir}
  end

  defp write_header(file, name) do
    IO.write(
      file,
      """
      {
        "@context": "https://www.w3.org/ns/activitystreams",
        "id": "#{name}.json",
        "type": "OrderedCollection",
        "orderedItems": [
      """
    )
  end

  defp write(query, dir, name, fun) do
    path = dir <> "/#{name}.json"

    with {:ok, file} <- File.open(path, [:write, :utf8]),
         :ok <- write_header(file, name) do
      counter = :counters.new(1, [])

      query
      |> Pleroma.RepoStreamer.chunk_stream(100)
      |> Stream.each(fn items ->
        Enum.each(items, fn i ->
          with {:ok, str} <- fun.(i),
               :ok <- IO.write(file, str <> ",\n") do
            :counters.add(counter, 1, 1)
          end
        end)
      end)
      |> Stream.run()

      total = :counters.get(counter, 1)

      with :ok <- :file.pwrite(file, {:eof, -2}, "\n],\n  \"totalItems\": #{total}}") do
        File.close(file)
      end
    end
  end

  def bookmarks(dir, %{id: user_id} = _user) do
    Bookmark
    |> where(user_id: ^user_id)
    |> join(:inner, [b], activity in assoc(b, :activity))
    |> select([b, a], %{id: b.id, object: fragment("(?)->>'object'", a.data)})
    |> write(dir, "bookmarks", fn a -> {:ok, "\"#{a.object}\""} end)
  end

  def likes(dir, user) do
    user.ap_id
    |> Activity.Queries.by_actor()
    |> Activity.Queries.by_type("Like")
    |> select([like], %{id: like.id, object: fragment("(?)->>'object'", like.data)})
    |> write(dir, "likes", fn a -> {:ok, "\"#{a.object}\""} end)
  end

  def statuses(dir, user) do
    opts =
      %{}
      |> Map.put(:type, ["Create", "Announce"])
      |> Map.put(:blocking_user, user)
      |> Map.put(:muting_user, user)
      |> Map.put(:reply_filtering_user, user)
      |> Map.put(:announce_filtering_user, user)
      |> Map.put(:user, user)

    [[user.ap_id], User.following(user), Pleroma.List.memberships(user)]
    |> Enum.concat()
    |> ActivityPub.fetch_activities_query(opts)
    |> write(dir, "outbox", fn a ->
      with {:ok, activity} <- Transmogrifier.prepare_outgoing(a.data) do
        activity |> Map.delete("@context") |> Jason.encode()
      end
    end)
  end
end
