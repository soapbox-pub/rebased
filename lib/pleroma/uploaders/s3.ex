# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Uploaders.S3 do
  @behaviour Pleroma.Uploaders.Uploader
  require Logger

  alias Pleroma.Config

  # The file name is re-encoded with S3's constraints here to comply with previous
  # links with less strict filenames
  @impl true
  def get_file(file) do
    config = Config.get([__MODULE__])
    bucket = Keyword.fetch!(config, :bucket)

    bucket_with_namespace =
      cond do
        truncated_namespace = Keyword.get(config, :truncated_namespace) ->
          truncated_namespace

        namespace = Keyword.get(config, :bucket_namespace) ->
          namespace <> ":" <> bucket

        true ->
          bucket
      end

    {:ok,
     {:url,
      Path.join([
        Keyword.fetch!(config, :public_endpoint),
        bucket_with_namespace,
        strict_encode(URI.decode(file))
      ])}}
  end

  @impl true
  def put_file(%Pleroma.Upload{} = upload) do
    config = Config.get([__MODULE__])
    bucket = Keyword.get(config, :bucket)
    streaming = Keyword.get(config, :streaming_enabled)

    s3_name = strict_encode(upload.path)

    op =
      if streaming do
        upload.tempfile
        |> ExAws.S3.Upload.stream_file()
        |> ExAws.S3.upload(bucket, s3_name, [
          {:acl, :public_read},
          {:content_type, upload.content_type}
        ])
      else
        {:ok, file_data} = File.read(upload.tempfile)

        ExAws.S3.put_object(bucket, s3_name, file_data, [
          {:acl, :public_read},
          {:content_type, upload.content_type}
        ])
      end

    case ExAws.request(op) do
      {:ok, _} ->
        {:ok, {:file, s3_name}}

      error ->
        Logger.error("#{__MODULE__}: #{inspect(error)}")
        {:error, "S3 Upload failed"}
    end
  end

  @impl true
  def delete_file(file) do
    [__MODULE__, :bucket]
    |> Config.get()
    |> ExAws.S3.delete_object(file)
    |> ExAws.request()
    |> case do
      {:ok, %{status_code: 204}} -> :ok
      error -> {:error, inspect(error)}
    end
  end

  @regex Regex.compile!("[^0-9a-zA-Z!.*/'()_-]")
  def strict_encode(name) do
    String.replace(name, @regex, "-")
  end
end
