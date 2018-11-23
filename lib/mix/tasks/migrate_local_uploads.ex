defmodule Mix.Tasks.MigrateLocalUploads do
  use Mix.Task
  import Mix.Ecto
  alias Pleroma.{Upload, Uploaders.Local, Uploaders.S3}
  require Logger

  @log_every 50
  @shortdoc "Migrate uploads from local to remote storage"

  def run([target_uploader | args]) do
    delete? = Enum.member?(args, "--delete")
    Application.ensure_all_started(:pleroma)

    local_path = Pleroma.Config.get!([Local, :uploads])
    uploader = Module.concat(Pleroma.Uploaders, target_uploader)

    unless Code.ensure_loaded?(uploader) do
      raise("The uploader #{inspect(uploader)} is not an existing/loaded module.")
    end

    target_enabled? = Pleroma.Config.get([Upload, :uploader]) == uploader

    unless target_enabled? do
      Pleroma.Config.put([Upload, :uploader], uploader)
    end

    Logger.info("Migrating files from local #{local_path} to #{to_string(uploader)}")

    if delete? do
      Logger.warn(
        "Attention: uploaded files will be deleted, hope you have backups! (--delete ; cancel with ^C)"
      )

      :timer.sleep(:timer.seconds(5))
    end

    uploads = File.ls!(local_path)
    total_count = length(uploads)

    uploads
    |> Task.async_stream(
      fn uuid ->
        u_path = Path.join(local_path, uuid)

        {name, path} =
          cond do
            File.dir?(u_path) ->
              files = for file <- File.ls!(u_path), do: {{file, uuid}, Path.join([u_path, file])}
              List.first(files)

            File.exists?(u_path) ->
              # {uuid, u_path}
              raise "should_dedupe local storage not supported yet sorry"
          end

        {:ok, _} =
          Upload.store({:from_local, name, path}, should_dedupe: false, uploader: uploader)

        if delete? do
          File.rm_rf!(u_path)
        end

        Logger.debug("uploaded: #{inspect(name)}")
      end,
      timeout: 150_000
    )
    |> Stream.chunk_every(@log_every)
    |> Enum.reduce(0, fn done, count ->
      count = count + length(done)
      Logger.info("Uploaded #{count}/#{total_count} files")
      count
    end)

    Logger.info("Done!")
  end

  def run(_) do
    Logger.error("Usage: migrate_local_uploads UploaderName [--delete]")
  end
end
