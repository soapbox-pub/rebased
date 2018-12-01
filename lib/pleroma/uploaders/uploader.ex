defmodule Pleroma.Uploaders.Uploader do
  @moduledoc """
  Defines the contract to put and get an uploaded file to any backend.
  """

  @doc """
  Instructs how to get the file from the backend.

  Used by `Pleroma.Plugs.UploadedMedia`.
  """
  @type get_method :: {:static_dir, directory :: String.t()} | {:url, url :: String.t()}
  @callback get_file(file :: String.t()) :: {:ok, get_method()}

  @doc """
  Put a file to the backend.

  Returns:

  * `:ok` which assumes `{:ok, upload.path}`
  * `{:ok, spec}` where spec is:
    * `{:file, filename :: String.t}` to handle reads with `get_file/1` (recommended)

    This allows to correctly proxy or redirect requests to the backend, while allowing to migrate backends without breaking any URL.
  * `{url, url :: String.t}` to bypass `get_file/2` and use the `url` directly in the activity.
  * `{:error, String.t}` error information if the file failed to be saved to the backend.


  """
  @callback put_file(Pleroma.Upload.t()) ::
              :ok | {:ok, {:file | :url, String.t()}} | {:error, String.t()}

  @spec put_file(module(), Pleroma.Upload.t()) ::
          {:ok, {:file | :url, String.t()}} | {:error, String.t()}
  def put_file(uploader, upload) do
    case uploader.put_file(upload) do
      :ok -> {:ok, {:file, upload.path}}
      other -> other
    end
  end
end
