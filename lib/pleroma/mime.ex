# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MIME do
  @moduledoc """
  Returns the mime-type of a binary and optionally a normalized file-name.
  """
  @read_bytes 35
  @pool __MODULE__.GenMagicPool

  def child_spec(_) do
    pool_size = Pleroma.Config.get!([:gen_magic_pool, :size])
    name = @pool

    %{
      id: __MODULE__,
      start: {GenMagic.Pool, :start_link, [[name: name, pool_size: pool_size]]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @spec file_mime_type(String.t(), String.t()) ::
          {:ok, content_type :: String.t(), filename :: String.t()} | {:error, any()} | :error
  def file_mime_type(path, filename) do
    with {:ok, content_type} <- file_mime_type(path),
         filename <- fix_extension(filename, content_type) do
      {:ok, content_type, filename}
    end
  end

  @spec file_mime_type(String.t()) :: {:ok, String.t()} | {:error, any()} | :error
  def file_mime_type(filename) do
    case GenMagic.Pool.perform(@pool, filename) do
      {:ok, %GenMagic.Result{mime_type: content_type}} -> {:ok, content_type}
      error -> error
    end
  end

  def bin_mime_type(binary, filename) do
    with {:ok, content_type} <- bin_mime_type(binary),
         filename <- fix_extension(filename, content_type) do
      {:ok, content_type, filename}
    end
  end

  @spec bin_mime_type(binary()) :: {:ok, String.t()} | :error
  def bin_mime_type(<<head::binary-size(@read_bytes), _::binary>>) do
    case GenMagic.Pool.perform(@pool, {:bytes, head}) do
      {:ok, %GenMagic.Result{mime_type: content_type}} -> {:ok, content_type}
      error -> error
    end
  end

  def bin_mime_type(_), do: :error

  defp fix_extension(filename, content_type) do
    parts = String.split(filename, ".")

    new_filename =
      if length(parts) > 1 do
        Enum.drop(parts, -1) |> Enum.join(".")
      else
        Enum.join(parts)
      end

    cond do
      content_type == "application/octet-stream" ->
        filename

      ext = List.first(MIME.extensions(content_type)) ->
        new_filename <> "." <> ext

      true ->
        Enum.join([new_filename, String.split(content_type, "/") |> List.last()], ".")
    end
  end
end
