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

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

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
    with {:ok, env} <- HTTP.get(url, [], http_client_opts()),
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
  @spec video_framegrab(String.t()) :: {:ok, binary()} | {:error, any()}
  def video_framegrab(url) do
    with executable when is_binary(executable) <- System.find_executable("ffmpeg"),
         {:ok, false} <- @cachex.exists?(:failed_media_helper_cache, url),
         {:ok, env} <- HTTP.get(url, [], http_client_opts()),
         {:ok, pid} <- StringIO.open(env.body) do
      body_stream = IO.binstream(pid, 1)

      task =
        Task.async(fn ->
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
        end)

      case Task.yield(task, 5_000) do
        {:ok, result} ->
          {:ok, result}

        _ ->
          Task.shutdown(task)
          @cachex.put(:failed_media_helper_cache, url, nil)
          {:error, {:ffmpeg, :timeout}}
      end
    else
      nil -> {:error, {:ffmpeg, :command_not_found}}
      {:error, _} = error -> error
    end
  end

  defp http_client_opts, do: Pleroma.Config.get([:media_proxy, :proxy_opts, :http], pool: :media)
end
