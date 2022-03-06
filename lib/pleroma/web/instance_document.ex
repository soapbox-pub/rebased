# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.InstanceDocument do
  alias Pleroma.Config
  alias Pleroma.Web.Endpoint

  @instance_documents %{
    "terms-of-service" => "/static/terms-of-service.html",
    "instance-panel" => "/instance/panel.html"
  }

  @spec get(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def get(document_name) do
    case Map.fetch(@instance_documents, document_name) do
      {:ok, path} -> {:ok, path}
      _ -> {:error, :not_found}
    end
  end

  @spec put(String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  def put(document_name, origin_path) do
    with {_, {:ok, destination_path}} <-
           {:instance_document, Map.fetch(@instance_documents, document_name)},
         :ok <- put_file(origin_path, destination_path) do
      {:ok, Path.join(Endpoint.url(), destination_path)}
    else
      {:instance_document, :error} -> {:error, :not_found}
      error -> error
    end
  end

  @spec delete(String.t()) :: :ok | {:error, atom()}
  def delete(document_name) do
    with {_, {:ok, path}} <- {:instance_document, Map.fetch(@instance_documents, document_name)},
         instance_static_dir_path <- instance_static_dir(path),
         :ok <- File.rm(instance_static_dir_path) do
      :ok
    else
      {:instance_document, :error} -> {:error, :not_found}
      {:error, :enoent} -> {:error, :not_found}
      error -> error
    end
  end

  defp put_file(origin_path, destination_path) do
    with destination <- instance_static_dir(destination_path),
         {_, :ok} <- {:mkdir_p, File.mkdir_p(Path.dirname(destination))},
         {_, {:ok, _}} <- {:copy, File.copy(origin_path, destination)} do
      :ok
    else
      {error, _} -> {:error, error}
    end
  end

  defp instance_static_dir(filename) do
    [:instance, :static_dir]
    |> Config.get!()
    |> Path.join(filename)
  end
end
