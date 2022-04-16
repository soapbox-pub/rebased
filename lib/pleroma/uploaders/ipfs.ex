# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Uploaders.IPFS do
  @behaviour Pleroma.Uploaders.Uploader
  require Logger

  alias Pleroma.Config
  alias Tesla.Multipart

  @placeholder "{CID}"
  def placeholder, do: @placeholder

  @impl true
  def get_file(file) do
    b_url = Pleroma.Upload.base_url()

    if String.contains?(b_url, @placeholder) do
      {:ok, {:url, String.replace(b_url, @placeholder, URI.decode(file))}}
    else
      {:error, "IPFS Get URL doesn't contain 'cid' placeholder"}
    end
  end

  @impl true
  def put_file(%Pleroma.Upload{} = upload) do
    config = Config.get([__MODULE__])
    post_base_url = Keyword.get(config, :post_gateway_url)

    mp =
      Multipart.new()
      |> Multipart.add_content_type_param("charset=utf-8")
      |> Multipart.add_file(upload.tempfile)

    final_url = Path.join([post_base_url, "/api/v0/add"])

    case Pleroma.HTTP.post(final_url, mp, [], params: ["cid-version": "1"]) do
      {:ok, ret} ->
        case Jason.decode(ret.body) do
          {:ok, ret} ->
            if Map.has_key?(ret, "Hash") do
              {:ok, {:file, ret["Hash"]}}
            else
              {:error, "JSON doesn't contain Hash value"}
            end

          error ->
            Logger.error("#{__MODULE__}: #{inspect(error)}")
            {:error, "JSON decode failed"}
        end

      error ->
        Logger.error("#{__MODULE__}: #{inspect(error)}")
        {:error, "IPFS Gateway upload failed"}
    end
  end

  @impl true
  def delete_file(file) do
    config = Config.get([__MODULE__])
    post_base_url = Keyword.get(config, :post_gateway_url)

    final_url = Path.join([post_base_url, "/api/v0/files/rm"])

    case Pleroma.HTTP.post(final_url, "", [], params: [arg: file]) do
      {:ok, %{status_code: 204}} -> :ok
      error -> {:error, inspect(error)}
    end
  end
end
