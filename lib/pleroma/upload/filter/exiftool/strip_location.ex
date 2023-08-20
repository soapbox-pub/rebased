# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.Exiftool.StripLocation do
  @moduledoc """
  Strips GPS related EXIF tags and overwrites the file in place.
  Also strips or replaces filesystem metadata e.g., timestamps.
  """
  @behaviour Pleroma.Upload.Filter

  @spec filter(Pleroma.Upload.t()) :: {:ok, any()} | {:error, String.t()}

  # Formats not compatible with exiftool at this time
  def filter(%Pleroma.Upload{content_type: "image/heic"}), do: {:ok, :noop}
  def filter(%Pleroma.Upload{content_type: "image/webp"}), do: {:ok, :noop}
  def filter(%Pleroma.Upload{content_type: "image/svg" <> _}), do: {:ok, :noop}

  def filter(%Pleroma.Upload{tempfile: file, content_type: "image" <> _}) do
    try do
      case System.cmd("exiftool", ["-overwrite_original", "-gps:all=", file], parallelism: true) do
        {_response, 0} -> {:ok, :filtered}
        {error, 1} -> {:error, error}
      end
    rescue
      e in ErlangError ->
        {:error, "#{__MODULE__}: #{inspect(e)}"}
    end
  end

  def filter(_), do: {:ok, :noop}
end
