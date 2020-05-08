# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Helpers.MogrifyHelper do
  @moduledoc """
  Handles common Mogrify operations.
  """

  @spec store_as_temporary_file(String.t(), binary()) :: {:ok, String.t()} | {:error, atom()}
  @doc "Stores binary content fetched from specified URL as a temporary file."
  def store_as_temporary_file(url, body) do
    path = Mogrify.temporary_path_for(%{path: url})
    with :ok <- File.write(path, body), do: {:ok, path}
  end

  @spec store_as_temporary_file(String.t(), String.t()) :: Mogrify.Image.t() | any()
  @doc "Modifies file at specified path by resizing to specified limit dimensions."
  def in_place_resize_to_limit(path, resize_dimensions) do
    path
    |> Mogrify.open()
    |> Mogrify.resize_to_limit(resize_dimensions)
    |> Mogrify.save(in_place: true)
  end
end
