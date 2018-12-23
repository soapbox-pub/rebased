# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Uploaders.MDII do
  alias Pleroma.Config

  @behaviour Pleroma.Uploaders.Uploader

  @httpoison Application.get_env(:pleroma, :httpoison)

  # MDII-hosted images are never passed through the MediaPlug; only local media.
  # Delegate to Pleroma.Uploaders.Local
  def get_file(file) do
    Pleroma.Uploaders.Local.get_file(file)
  end

  def put_file(upload) do
    cgi = Config.get([Pleroma.Uploaders.MDII, :cgi])
    files = Config.get([Pleroma.Uploaders.MDII, :files])

    {:ok, file_data} = File.read(upload.tempfile)

    extension = String.split(upload.name, ".") |> List.last()
    query = "#{cgi}?#{extension}"

    with {:ok, %{status: 200, body: body}} <- @httpoison.post(query, file_data) do
      remote_file_name = String.split(body) |> List.first()
      public_url = "#{files}/#{remote_file_name}.#{extension}"
      {:ok, {:url, public_url}}
    else
      _ -> Pleroma.Uploaders.Local.put_file(upload)
    end
  end
end
