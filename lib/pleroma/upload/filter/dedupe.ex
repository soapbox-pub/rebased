# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.Dedupe do
  @behaviour Pleroma.Upload.Filter
  alias Pleroma.Upload

  def filter(%Upload{name: name, tempfile: tempfile} = upload) do
    extension =
      name
      |> String.split(".")
      |> List.last()

    shasum =
      :crypto.hash(:sha256, File.read!(tempfile))
      |> Base.encode16(case: :lower)

    filename = shasum <> "." <> extension

    {:ok, :filtered, %Upload{upload | id: shasum, path: shard_path(filename)}}
  end

  def filter(_), do: {:ok, :noop}

  @spec shard_path(String.t()) :: String.t()
  def shard_path(
        <<a::binary-size(2), b::binary-size(2), c::binary-size(2), _::binary>> = filename
      ) do
    Path.join([a, b, c, filename])
  end
end
