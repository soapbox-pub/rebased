# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Helpers.MediaHelper do
  @moduledoc """
  Handles common media-related operations.
  """

  alias Pleroma.HTTP
  alias Vix.Vips.Operation

  require Logger

  def missing_dependencies do
    Enum.reduce([ffmpeg: "ffmpeg"], [], fn {sym, executable}, acc ->
      if Pleroma.Utils.command_available?(executable) do
        acc
      else
        [sym | acc]
      end
    end)
  end

  def image_resize(url, options) do
    with {:ok, env} <- HTTP.get(url, [], pool: :media),
         {:ok, resized} <-
           Operation.thumbnail_buffer(env.body, options.max_width,
             height: options.max_height,
             size: :VIPS_SIZE_DOWN
           ) do
      if options[:format] == "png" do
        Operation.pngsave_buffer(resized, Q: options[:quality])
      else
        Operation.jpegsave_buffer(resized, Q: options[:quality], interlace: true)
      end
    else
      {:error, _} = error -> error
    end
  end

  # Note: video thumbnail is intentionally not resized (always has original dimensions)
  def video_framegrab(url) do
    with executable when is_binary(executable) <- System.find_executable("ffmpeg"),
         {:ok, env} <- HTTP.get(url, [], pool: :media),
         {:ok, pid} <- StringIO.open(env.body) do
      body_stream = IO.binstream(pid, 1)

      Exile.stream!(
        [
          executable,
          "-i",
          "pipe:0",
          "-vframes",
          "1",
          "-f",
          "mjpeg",
          "pipe:1"
        ],
        input: body_stream,
        ignore_epipe: true,
        stderr: :disable
      )
      |> Enum.into(<<>>)
    else
      nil -> {:error, {:ffmpeg, :command_not_found}}
      {:error, _} = error -> error
    end
  end
end
