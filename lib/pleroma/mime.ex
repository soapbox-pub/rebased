defmodule Pleroma.MIME do
  @moduledoc """
  Returns the mime-type of a binary and optionally a normalized file-name. Requires at least (the first) 8 bytes.
  """
  @default "application/octet-stream"

  @spec file_mime_type(String.t()) ::
          {:ok, content_type :: String.t(), filename :: String.t()} | {:error, any()} | :error
  def file_mime_type(path, filename) do
    with {:ok, content_type} <- file_mime_type(path),
         filename <- fix_extension(filename, content_type) do
      {:ok, content_type, filename}
    end
  end

  @spec file_mime_type(String.t()) :: {:ok, String.t()} | {:error, any()} | :error
  def file_mime_type(filename) do
    File.open(filename, [:read], fn f ->
      check_mime_type(IO.binread(f, 8))
    end)
  end

  def bin_mime_type(binary, filename) do
    with {:ok, content_type} <- bin_mime_type(binary),
         filename <- fix_extension(filename, content_type) do
      {:ok, content_type, filename}
    end
  end

  @spec bin_mime_type(binary()) :: {:ok, String.t()} | :error
  def bin_mime_type(<<head::binary-size(8), _::binary>>) do
    {:ok, check_mime_type(head)}
  end

  def mime_type(<<_::binary>>), do: {:ok, @default}

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

  defp check_mime_type(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>) do
    "image/png"
  end

  defp check_mime_type(<<0x47, 0x49, 0x46, 0x38, _, 0x61, _, _>>) do
    "image/gif"
  end

  defp check_mime_type(<<0xFF, 0xD8, 0xFF, _, _, _, _, _>>) do
    "image/jpeg"
  end

  defp check_mime_type(<<0x1A, 0x45, 0xDF, 0xA3, _, _, _, _>>) do
    "video/webm"
  end

  defp check_mime_type(<<0x00, 0x00, 0x00, _, 0x66, 0x74, 0x79, 0x70>>) do
    "video/mp4"
  end

  defp check_mime_type(<<0x49, 0x44, 0x33, _, _, _, _, _>>) do
    "audio/mpeg"
  end

  defp check_mime_type(<<255, 251, _, 68, 0, 0, 0, 0>>) do
    "audio/mpeg"
  end

  defp check_mime_type(<<0x4F, 0x67, 0x67, 0x53, 0x00, 0x02, 0x00, 0x00>>) do
    "audio/ogg"
  end

  defp check_mime_type(<<0x52, 0x49, 0x46, 0x46, _, _, _, _>>) do
    "audio/wav"
  end

  defp check_mime_type(_) do
    @default
  end
end
