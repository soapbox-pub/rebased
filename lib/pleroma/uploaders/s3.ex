# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Uploaders.S3 do
  @behaviour Pleroma.Uploaders.Uploader
  require Logger

  # The file name is re-encoded with S3's constraints here to comply with previous
  # links with less strict filenames
  def get_file(file) do
    config = Pleroma.Config.get([__MODULE__])
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

  def put_file(%Pleroma.Upload{} = upload) do
    config = Pleroma.Config.get([__MODULE__])
    bucket = Keyword.get(config, :bucket)

    {:ok, file_data} = File.read(upload.tempfile)

    s3_name = strict_encode(upload.path)

    op =
      ExAws.S3.put_object(bucket, s3_name, file_data, [
        {:acl, :public_read},
        {:content_type, upload.content_type}
      ])

    case ExAws.request(op) do
      {:ok, _} ->
        {:ok, {:file, s3_name}}

      error ->
        Logger.error("#{__MODULE__}: #{inspect(error)}")
        {:error, "S3 Upload failed"}
    end
  end

  @regex Regex.compile!("[^0-9a-zA-Z!.*/'()_-]")
  def strict_encode(name) do
    String.replace(name, @regex, "-")
  end
end
