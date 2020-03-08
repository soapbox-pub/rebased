# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.AnonymizeFilename do
  @moduledoc """
  Replaces the original filename with a pre-defined text or randomly generated string.

  Should be used after `Pleroma.Upload.Filter.Dedupe`.
  """
  @behaviour Pleroma.Upload.Filter

  alias Pleroma.Config
  alias Pleroma.Upload

  def filter(%Upload{name: name} = upload) do
    extension = List.last(String.split(name, "."))
    name = predefined_name(extension) || random(extension)
    {:ok, %Upload{upload | name: name}}
  end

  @spec predefined_name(String.t()) :: String.t() | nil
  defp predefined_name(extension) do
    with name when not is_nil(name) <- Config.get([__MODULE__, :text]),
         do: String.replace(name, "{extension}", extension)
  end

  defp random(extension) do
    string =
      10
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64(padding: false)

    string <> "." <> extension
  end
end
