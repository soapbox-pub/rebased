# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.Backup do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query
  import Pleroma.Web.Gettext

  require Pleroma.Constants

  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.UserView
  alias Pleroma.Workers.BackupWorker

  schema "backups" do
    field(:content_type, :string)
    field(:file_name, :string)
    field(:file_size, :integer, default: 0)
    field(:processed, :boolean, default: false)

    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)

    timestamps()
  end

  def create(user, admin_id \\ nil) do
    with :ok <- validate_limit(user, admin_id),
         {:ok, backup} <- user |> new() |> Repo.insert() do
      BackupWorker.process(backup, admin_id)
    end
  end

  def new(user) do
    rand_str = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    datetime = Calendar.NaiveDateTime.Format.iso8601_basic(NaiveDateTime.utc_now())
    name = "archive-#{user.nickname}-#{datetime}-#{rand_str}.zip"

    %__MODULE__{
      user_id: user.id,
      content_type: "application/zip",
      file_name: name
    }
  end

  def delete(backup) do
    uploader = Pleroma.Config.get([Pleroma.Upload, :uploader])

    with :ok <- uploader.delete_file(Path.join("backups", backup.file_name)) do
      Repo.delete(backup)
    end
  end

  defp validate_limit(_user, admin_id) when is_binary(admin_id), do: :ok

  defp validate_limit(user, nil) do
    case get_last(user.id) do
      %__MODULE__{inserted_at: inserted_at} ->
        days = Pleroma.Config.get([__MODULE__, :limit_days])
        diff = Timex.diff(NaiveDateTime.utc_now(), inserted_at, :days)

        if diff > days do
          :ok
        else
          {:error,
           dngettext(
             "errors",
             "Last export was less than a day ago",
             "Last export was less than %{days} days ago",
             days,
             days: days
           )}
        end

      nil ->
        :ok
    end
  end

  def get_last(user_id) do
    __MODULE__
    |> where(user_id: ^user_id)
    |> order_by(desc: :id)
    |> limit(1)
    |> Repo.one()
  end

  def list(%User{id: user_id}) do
    __MODULE__
    |> where(user_id: ^user_id)
    |> order_by(desc: :id)
    |> Repo.all()
  end

  def remove_outdated(%__MODULE__{id: latest_id, user_id: user_id}) do
    __MODULE__
    |> where(user_id: ^user_id)
    |> where([b], b.id != ^latest_id)
    |> Repo.all()
    |> Enum.each(&BackupWorker.delete/1)
  end

  def get(id), do: Repo.get(__MODULE__, id)

  def process(%__MODULE__{} = backup) do
    with {:ok, zip_file} <- export(backup),
         {:ok, %{size: size}} <- File.stat(zip_file),
         {:ok, _upload} <- upload(backup, zip_file) do
      backup
      |> cast(%{file_size: size, processed: true}, [:file_size, :processed])
      |> Repo.update()
    end
  end

  @files ['actor.json', 'outbox.json', 'likes.json', 'bookmarks.json']
  def export(%__MODULE__{} = backup) do
    backup = Repo.preload(backup, :user)
    name = String.trim_trailing(backup.file_name, ".zip")
    dir = dir(name)

    with :ok <- File.mkdir(dir),
         :ok <- actor(dir, backup.user),
         :ok <- statuses(dir, backup.user),
         :ok <- likes(dir, backup.user),
         :ok <- bookmarks(dir, backup.user),
         {:ok, zip_path} <- :zip.create(String.to_charlist(dir <> ".zip"), @files, cwd: dir),
         {:ok, _} <- File.rm_rf(dir) do
      {:ok, to_string(zip_path)}
    end
  end

  def dir(name) do
    dir = Pleroma.Config.get([__MODULE__, :dir]) || System.tmp_dir!()
    Path.join(dir, name)
  end

  def upload(%__MODULE__{} = backup, zip_path) do
    uploader = Pleroma.Config.get([Pleroma.Upload, :uploader])

    upload = %Pleroma.Upload{
      name: backup.file_name,
      tempfile: zip_path,
      content_type: backup.content_type,
      path: Path.join("backups", backup.file_name)
    }

    with {:ok, _} <- Pleroma.Uploaders.Uploader.put_file(uploader, upload),
         :ok <- File.rm(zip_path) do
      {:ok, upload}
    end
  end

  defp actor(dir, user) do
    with {:ok, json} <-
           UserView.render("user.json", %{user: user})
           |> Map.merge(%{"likes" => "likes.json", "bookmarks" => "bookmarks.json"})
           |> Jason.encode() do
      File.write(Path.join(dir, "actor.json"), json)
    end
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
    path = Path.join(dir, "#{name}.json")

    with {:ok, file} <- File.open(path, [:write, :utf8]),
         :ok <- write_header(file, name) do
      total =
        query
        |> Pleroma.Repo.chunk_stream(100)
        |> Enum.reduce(0, fn i, acc ->
          with {:ok, data} <- fun.(i),
               {:ok, str} <- Jason.encode(data),
               :ok <- IO.write(file, str <> ",\n") do
            acc + 1
          else
            _ -> acc
          end
        end)

      with :ok <- :file.pwrite(file, {:eof, -2}, "\n],\n  \"totalItems\": #{total}}") do
        File.close(file)
      end
    end
  end

  defp bookmarks(dir, %{id: user_id} = _user) do
    Bookmark
    |> where(user_id: ^user_id)
    |> join(:inner, [b], activity in assoc(b, :activity))
    |> select([b, a], %{id: b.id, object: fragment("(?)->>'object'", a.data)})
    |> write(dir, "bookmarks", fn a -> {:ok, a.object} end)
  end

  defp likes(dir, user) do
    user.ap_id
    |> Activity.Queries.by_actor()
    |> Activity.Queries.by_type("Like")
    |> select([like], %{id: like.id, object: fragment("(?)->>'object'", like.data)})
    |> write(dir, "likes", fn a -> {:ok, a.object} end)
  end

  defp statuses(dir, user) do
    opts =
      %{}
      |> Map.put(:type, ["Create", "Announce"])
      |> Map.put(:actor_id, user.ap_id)

    [
      [Pleroma.Constants.as_public(), user.ap_id],
      User.following(user),
      Pleroma.List.memberships(user)
    ]
    |> Enum.concat()
    |> ActivityPub.fetch_activities_query(opts)
    |> write(dir, "outbox", fn a ->
      with {:ok, activity} <- Transmogrifier.prepare_outgoing(a.data) do
        {:ok, Map.delete(activity, "@context")}
      end
    end)
  end
end
