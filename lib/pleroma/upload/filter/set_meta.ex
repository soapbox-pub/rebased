# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.SetMeta do
  @moduledoc """
  Extracts metadata about the upload, such as width/height
  """
  require Logger

  @behaviour Pleroma.Upload.Filter

  @spec filter(Pleroma.Upload.t()) ::
          {:ok, :filtered, Pleroma.Upload.t()} | {:ok, :noop} | {:error, String.t()}
  def filter(%Pleroma.Upload{tempfile: file, content_type: "image" <> _} = upload) do
    try do
      image =
        file
        |> Mogrify.open()
        |> Mogrify.verbose()

      upload =
        upload
        |> Map.put(:width, image.width)
        |> Map.put(:height, image.height)

      {:ok, :filtered, upload}
    rescue
      e in ErlangError ->
        Logger.warn("#{__MODULE__}: #{inspect(e)}")
        {:ok, :noop}
    end
  end

  def filter(_), do: {:ok, :noop}
end
