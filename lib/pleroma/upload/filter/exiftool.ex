# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.Exiftool do
  @moduledoc """
  Strips GPS related EXIF tags and overwrites the file in place.
  Also strips or replaces filesystem metadata e.g., timestamps.
  """
  @behaviour Pleroma.Upload.Filter

  def filter(%Pleroma.Upload{tempfile: file, content_type: "image" <> _}) do
    System.cmd("exiftool", ["-overwrite_original", "-gps:all=", file], parallelism: true)
    :ok
  end

  def filter(_), do: :ok
end
