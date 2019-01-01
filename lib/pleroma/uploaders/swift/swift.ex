# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Uploaders.Swift.Client do
  use HTTPoison.Base

  def process_url(url) do
    Enum.join(
      [Pleroma.Config.get!([Pleroma.Uploaders.Swift, :storage_url]), url],
      "/"
    )
  end

  def upload_file(filename, body, content_type) do
    token = Pleroma.Uploaders.Swift.Keystone.get_token()

    case put("#{filename}", body, "X-Auth-Token": token, "Content-Type": content_type) do
      {:ok, %Tesla.Env{status: 201}} ->
        {:ok, {:file, filename}}

      {:ok, %Tesla.Env{status: 401}} ->
        {:error, "Unauthorized, Bad Token"}

      {:error, _} ->
        {:error, "Swift Upload Error"}
    end
  end
end
