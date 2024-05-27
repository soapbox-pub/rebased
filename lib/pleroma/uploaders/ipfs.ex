# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Uploaders.IPFS do
  @behaviour Pleroma.Uploaders.Uploader
  require Logger

  alias Tesla.Multipart

  @config_impl Application.compile_env(:pleroma, [__MODULE__, :config_impl], Pleroma.Config)

  defp get_final_url(method) do
    config = @config_impl.get([__MODULE__])
    post_base_url = Keyword.get(config, :post_gateway_url)

    Path.join([post_base_url, method])
  end

  def put_file_endpoint do
    get_final_url("/api/v0/add")
  end

  def delete_file_endpoint do
    get_final_url("/api/v0/files/rm")
  end

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
    mp =
      Multipart.new()
      |> Multipart.add_content_type_param("charset=utf-8")
      |> Multipart.add_file(upload.tempfile)

    case Pleroma.HTTP.post(put_file_endpoint(), mp, [], params: ["cid-version": "1"]) do
      {:ok, ret} ->
        case Jason.decode(ret.body) do
          {:ok, ret} ->
            if Map.has_key?(ret, "Hash") do
              {:ok, {:file, ret["Hash"]}}
            else
              {:error, "JSON doesn't contain Hash key"}
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
    case Pleroma.HTTP.post(delete_file_endpoint(), "", [], params: [arg: file]) do
      {:ok, %{status: 204}} -> :ok
      error -> {:error, inspect(error)}
    end
  end
end
