# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.Backup do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query
  import Pleroma.Web.Gettext

  require Logger
  require Pleroma.Constants

  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.User.Backup.State
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.UserView
  alias Pleroma.Workers.BackupWorker

  schema "backups" do
    field(:content_type, :string)
    field(:file_name, :string)
    field(:file_size, :integer, default: 0)
    field(:processed, :boolean, default: false)
    field(:state, State, default: :invalid)
    field(:processed_number, :integer, default: 0)

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
      file_name: name,
      state: :pending
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

  defp set_state(backup, state, processed_number \\ nil) do
    struct =
      %{state: state}
      |> Pleroma.Maps.put_if_present(:processed_number, processed_number)

    backup
    |> cast(struct, [:state, :processed_number])
    |> Repo.update()
  end

  def process(%__MODULE__{} = backup) do
    set_state(backup, :running, 0)

    current_pid = self()

    task =
      Task.Supervisor.async_nolink(
        Pleroma.TaskSupervisor,
        __MODULE__,
        :do_process,
        [backup, current_pid]
      )

    wait_backup(backup, backup.processed_number, task)
  end

  def do_process(backup, current_pid) do
    with {:ok, zip_file} <- export(backup, current_pid),
         {:ok, %{size: size}} <- File.stat(zip_file),
         {:ok, _upload} <- upload(backup, zip_file) do
      backup
      |> cast(
        %{
          file_size: size,
          processed: true,
          state: :complete
        },
        [:file_size, :processed, :state]
      )
      |> Repo.update()
    end
  end

  defp wait_backup(backup, current_processed, task) do
    wait_time = Pleroma.Config.get([__MODULE__, :process_wait_time])

    receive do
      {:progress, new_processed} ->
        total_processed = current_processed + new_processed

        set_state(backup, :running, total_processed)
        wait_backup(backup, total_processed, task)

      {:DOWN, _ref, _proc, _pid, reason} ->
        backup = get(backup.id)

        if reason != :normal do
          Logger.error("Backup #{backup.id} process ended abnormally: #{inspect(reason)}")

          {:ok, backup} = set_state(backup, :failed)

          cleanup(backup)

          {:error,
           %{
             backup: backup,
             reason: :exit,
             details: reason
           }}
        else
          {:ok, backup}
        end
    after
      wait_time ->
        Logger.error(
          "Backup #{backup.id} timed out after no response for #{wait_time}ms, terminating"
        )

        Task.Supervisor.terminate_child(Pleroma.TaskSupervisor, task.pid)

        {:ok, backup} = set_state(backup, :failed)

        cleanup(backup)

        {:error,
         %{
           backup: backup,
           reason: :timeout
         }}
    end
  end

  @files ['actor.json', 'outbox.json', 'likes.json', 'bookmarks.json']
  def export(%__MODULE__{} = backup, caller_pid) do
    backup = Repo.preload(backup, :user)
    dir = backup_tempdir(backup)

    with :ok <- File.mkdir(dir),
         :ok <- actor(dir, backup.user, caller_pid),
         :ok <- statuses(dir, backup.user, caller_pid),
         :ok <- likes(dir, backup.user, caller_pid),
         :ok <- bookmarks(dir, backup.user, caller_pid),
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

  defp actor(dir, user, caller_pid) do
    with {:ok, json} <-
           UserView.render("user.json", %{user: user})
           |> Map.merge(%{"likes" => "likes.json", "bookmarks" => "bookmarks.json"})
           |> Jason.encode() do
      send(caller_pid, {:progress, 1})
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

  defp should_report?(num, chunk_size), do: rem(num, chunk_size) == 0

  defp backup_tempdir(backup) do
    name = String.trim_trailing(backup.file_name, ".zip")
    dir(name)
  end

  defp cleanup(backup) do
    dir = backup_tempdir(backup)
    File.rm_rf(dir)
  end

  defp write(query, dir, name, fun, caller_pid) do
    path = Path.join(dir, "#{name}.json")

    chunk_size = Pleroma.Config.get([__MODULE__, :process_chunk_size])

    with {:ok, file} <- File.open(path, [:write, :utf8]),
         :ok <- write_header(file, name) do
      total =
        query
        |> Pleroma.Repo.chunk_stream(chunk_size, _returns_as = :one, timeout: :infinity)
        |> Enum.reduce(0, fn i, acc ->
          with {:ok, data} <-
                 (try do
                    fun.(i)
                  rescue
                    e -> {:error, e}
                  end),
               {:ok, str} <- Jason.encode(data),
               :ok <- IO.write(file, str <> ",\n") do
            if should_report?(acc + 1, chunk_size) do
              send(caller_pid, {:progress, chunk_size})
            end

            acc + 1
          else
            {:error, e} ->
              Logger.warning(
                "Error processing backup item: #{inspect(e)}\n The item is: #{inspect(i)}"
              )

              acc

            _ ->
              acc
          end
        end)

      send(caller_pid, {:progress, rem(total, chunk_size)})

      with :ok <- :file.pwrite(file, {:eof, -2}, "\n],\n  \"totalItems\": #{total}}") do
        File.close(file)
      end
    end
  end

  defp bookmarks(dir, %{id: user_id} = _user, caller_pid) do
    Bookmark
    |> where(user_id: ^user_id)
    |> join(:inner, [b], activity in assoc(b, :activity))
    |> select([b, a], %{id: b.id, object: fragment("(?)->>'object'", a.data)})
    |> write(dir, "bookmarks", fn a -> {:ok, a.object} end, caller_pid)
  end

  defp likes(dir, user, caller_pid) do
    user.ap_id
    |> Activity.Queries.by_actor()
    |> Activity.Queries.by_type("Like")
    |> select([like], %{id: like.id, object: fragment("(?)->>'object'", like.data)})
    |> write(dir, "likes", fn a -> {:ok, a.object} end, caller_pid)
  end

  defp statuses(dir, user, caller_pid) do
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
    |> write(
      dir,
      "outbox",
      fn a ->
        with {:ok, activity} <- Transmogrifier.prepare_outgoing(a.data) do
          {:ok, Map.delete(activity, "@context")}
        end
      end,
      caller_pid
    )
  end
end
