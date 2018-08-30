defmodule Pleroma.Uploaders.Uploader do
  @moduledoc """
  Defines the contract to put an uploaded file to any backend.
  """

  @doc """
  Put a file to the backend.

  Returns a `String.t` containing the path of the uploaded file.
  """
  @callback put_file(
              name :: String.t(),
              uuid :: String.t(),
              file :: File.t(),
              content_type :: String.t(),
              should_dedupe :: Boolean.t()
            ) :: {:ok, String.t()} | {:error, String.t()}
end
