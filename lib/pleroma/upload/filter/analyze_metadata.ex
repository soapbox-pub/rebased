# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.AnalyzeMetadata do
  @moduledoc """
  Extracts metadata about the upload, such as width/height
  """
  require Logger

  alias Vix.Vips.Image
  alias Vix.Vips.Operation

  @behaviour Pleroma.Upload.Filter

  @spec filter(Pleroma.Upload.t()) ::
          {:ok, :filtered, Pleroma.Upload.t()} | {:ok, :noop} | {:error, String.t()}
  def filter(%Pleroma.Upload{tempfile: file, content_type: "image" <> _} = upload) do
    try do
      {:ok, image} = Image.new_from_file(file)
      {width, height} = {Image.width(image), Image.height(image)}

      upload =
        upload
        |> Map.put(:width, width)
        |> Map.put(:height, height)
        |> Map.put(:blurhash, get_blurhash(image))

      {:ok, :filtered, upload}
    rescue
      e in ErlangError ->
        Logger.warning("#{__MODULE__}: #{inspect(e)}")
        {:ok, :noop}
    end
  end

  def filter(%Pleroma.Upload{tempfile: file, content_type: "video" <> _} = upload) do
    try do
      result = media_dimensions(file)

      upload =
        upload
        |> Map.put(:width, result.width)
        |> Map.put(:height, result.height)

      {:ok, :filtered, upload}
    rescue
      e in ErlangError ->
        Logger.warning("#{__MODULE__}: #{inspect(e)}")
        {:ok, :noop}
    end
  end

  def filter(_), do: {:ok, :noop}

  defp get_blurhash(file) do
    with {:ok, blurhash} <- vips_blurhash(file) do
      blurhash
    else
      _ -> nil
    end
  end

  defp media_dimensions(file) do
    with executable when is_binary(executable) <- System.find_executable("ffprobe"),
         args = [
           "-v",
           "error",
           "-show_entries",
           "stream=width,height",
           "-of",
           "csv=p=0:s=x",
           file
         ],
         {result, 0} <- System.cmd(executable, args),
         [width, height] <-
           String.split(String.trim(result), "x") |> Enum.map(&String.to_integer(&1)) do
      %{width: width, height: height}
    else
      nil -> {:error, {:ffprobe, :command_not_found}}
      error -> {:error, error}
    end
  end

  defp vips_blurhash(%Vix.Vips.Image{} = image) do
    with {:ok, resized_image} <- Operation.thumbnail_image(image, 100),
         {height, width} <- {Image.height(resized_image), Image.width(resized_image)},
         max <- max(height, width),
         {x, y} <- {max(round(width * 5 / max), 1), max(round(height * 5 / max), 1)} do
      {:ok, rgb} =
        if Image.has_alpha?(resized_image) do
          # remove alpha channel
          case Operation.extract_band(resized_image, 0, n: 3) do
            {:ok, data} ->
              Image.write_to_binary(data)

            _ ->
              Image.write_to_binary(resized_image)
          end
        else
          Image.write_to_binary(resized_image)
        end

      Blurhash.encode(rgb, width, height, x, y)
    else
      _ -> nil
    end
  end
end
