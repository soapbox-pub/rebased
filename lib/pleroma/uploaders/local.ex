defmodule Pleroma.Uploaders.Local do
  @behaviour Pleroma.Uploaders.Uploader

  alias Pleroma.Web

  def get_file(_) do
    {:ok, {:static_dir, upload_path()}}
  end

  def put_file(upload) do
    {local_path, file} =
      case Enum.reverse(String.split(upload.path, "/", trim: true)) do
        [file] ->
          {upload_path(), file}

        [file | folders] ->
          path = Path.join([upload_path()] ++ Enum.reverse(folders))
          File.mkdir_p!(path)
          {path, file}
      end

    result_file = Path.join(local_path, file)

    unless File.exists?(result_file) do
      File.cp!(upload.tempfile, result_file)
    end

    :ok
  end

  def upload_path do
    Pleroma.Config.get!([__MODULE__, :uploads])
  end
end
