defmodule Mix.Tasks.Pleroma.Uploads do
  use Mix.Task
  alias Pleroma.{Upload, Uploaders.Local}
  alias Mix.Tasks.Pleroma.Common
  require Logger

  @log_every 50
  @shortdoc "Migrate uploads from local to remote storage"
  @doc """
   Manages uploads
   ## Migrate uploads from local to remote storage

  """
  def run(["migrate_local", target_uploader | args]) do
    delete? = Enum.member?(args, "--delete")
    Common.start_pleroma()
    local_path = Pleroma.Config.get!([Local, :uploads])
    uploader = Module.concat(Pleroma.Uploaders, target_uploader)

    unless Code.ensure_loaded?(uploader) do
      raise("The uploader #{inspect(uploader)} is not an existing/loaded module.")
    end

    target_enabled? = Pleroma.Config.get([Upload, :uploader]) == uploader

    unless target_enabled? do
      Pleroma.Config.put([Upload, :uploader], uploader)
    end

    Mix.shell().info("Migrating files from local #{local_path} to #{to_string(uploader)}")

    if delete? do
      Mix.shell().info(
        "Attention: uploaded files will be deleted, hope you have backups! (--delete ; cancel with ^C)"
      )

      :timer.sleep(:timer.seconds(5))
    end

    uploads =
      File.ls!(local_path)
      |> Enum.map(fn id ->
        root_path = Path.join(local_path, id)

        cond do
          File.dir?(root_path) ->
            files = for file <- File.ls!(root_path), do: {id, file, Path.join([root_path, file])}

            case List.first(files) do
              {id, file, path} ->
                {%Pleroma.Upload{id: id, name: file, path: id <> "/" <> file, tempfile: path},
                 root_path}

              _ ->
                nil
            end

          File.exists?(root_path) ->
            file = Path.basename(id)
            [hash, _ext] = String.split(id, ".")
            {%Pleroma.Upload{id: hash, name: file, path: file, tempfile: root_path}, root_path}

          true ->
            nil
        end
      end)
      |> Enum.filter(& &1)

    total_count = length(uploads)
    Mix.shell().info("Found #{total_count} uploads")

    uploads
    |> Task.async_stream(
      fn {upload, root_path} ->
        case Upload.store(upload, uploader: uploader, filters: [], size_limit: nil) do
          {:ok, _} ->
            if delete?, do: File.rm_rf!(root_path)
            Logger.debug("uploaded: #{inspect(upload.path)} #{inspect(upload)}")
            :ok

          error ->
            Mix.shell().error("failed to upload #{inspect(upload.path)}: #{inspect(error)}")
        end
      end,
      timeout: 150_000
    )
    |> Stream.chunk_every(@log_every)
    |> Enum.reduce(0, fn done, count ->
      count = count + length(done)
      Mix.shell().info("Uploaded #{count}/#{total_count} files")
      count
    end)

    Mix.shell().info("Done!")
  end
end
