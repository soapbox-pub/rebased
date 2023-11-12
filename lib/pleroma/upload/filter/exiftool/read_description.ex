# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.Exiftool.ReadDescription do
  @moduledoc """
  Gets a valid description from the related EXIF tags and provides them in the response if no description is provided yet.
  It will first check ImageDescription, when that doesn't probide a valid description, it will check iptc:Caption-Abstract.
  A valid description means the fields are filled in and not too long (see `:instance, :description_limit`).
  """
  @behaviour Pleroma.Upload.Filter

  @spec filter(Pleroma.Upload.t()) :: {:ok, any()} | {:error, String.t()}

  def filter(%Pleroma.Upload{description: description})
      when is_binary(description),
      do: {:ok, :noop}

  def filter(%Pleroma.Upload{tempfile: file} = upload),
    do: {:ok, :filtered, upload |> Map.put(:description, read_description_from_exif_data(file))}

  def filter(_, _), do: {:ok, :noop}

  defp read_description_from_exif_data(file) do
    nil
    |> read_when_empty(file, "-ImageDescription")
    |> read_when_empty(file, "-iptc:Caption-Abstract")
  end

  defp read_when_empty(current_description, _, _) when is_binary(current_description),
    do: current_description

  defp read_when_empty(_, file, tag) do
    try do
      {tag_content, 0} =
        System.cmd("exiftool", ["-b", "-s3", tag, file],
          stderr_to_stdout: false,
          parallelism: true
        )

      tag_content = String.trim(tag_content)

      if tag_content != "" and
           String.length(tag_content) <=
             Pleroma.Config.get([:instance, :description_limit]),
         do: tag_content,
         else: nil
    rescue
      _ in ErlangError -> nil
    end
  end
end
