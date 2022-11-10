# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.HeifToJpeg do
  @behaviour Pleroma.Upload.Filter
  alias Pleroma.Upload
  alias Vix.Vips.Operation

  @type conversion :: action :: String.t() | {action :: String.t(), opts :: String.t()}
  @type conversions :: conversion() | [conversion()]

  @spec filter(Pleroma.Upload.t()) :: {:ok, :atom} | {:error, String.t()}
  def filter(%Pleroma.Upload{content_type: "image/avif"} = upload), do: apply_filter(upload)
  def filter(%Pleroma.Upload{content_type: "image/heic"} = upload), do: apply_filter(upload)
  def filter(%Pleroma.Upload{content_type: "image/heif"} = upload), do: apply_filter(upload)

  def filter(_), do: {:ok, :noop}

  defp apply_filter(%Pleroma.Upload{name: name, path: path, tempfile: tempfile} = upload) do
    ext = String.split(path, ".") |> List.last()

    try do
      name = name |> String.replace_suffix(ext, "jpg")
      path = path |> String.replace_suffix(ext, "jpg")
      {:ok, {vixdata, _vixflags}} = Operation.heifload(tempfile)
      {:ok, jpegdata} = Operation.jpegsave_buffer(vixdata)
      :ok = File.write(tempfile, jpegdata)

      {:ok, :filtered, %Upload{upload | name: name, path: path, content_type: "image/jpeg"}}
    rescue
      e in ErlangError ->
        {:error, "#{__MODULE__}: #{inspect(e)}"}
    end
  end
end
