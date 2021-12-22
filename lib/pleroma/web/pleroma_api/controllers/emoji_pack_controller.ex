# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EmojiPackController do
  use Pleroma.Web, :controller

  alias Pleroma.Emoji.Pack

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    Pleroma.Web.Plugs.OAuthScopesPlug,
    %{scopes: ["admin:write"]}
    when action in [
           :import_from_filesystem,
           :remote,
           :download,
           :create,
           :update,
           :delete
         ]
  )

  plug(:skip_auth when action in [:index, :archive, :show])

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaEmojiPackOperation

  def remote(conn, params) do
    with {:ok, packs} <-
           Pack.list_remote(url: params.url, page_size: params.page_size, page: params.page) do
      json(conn, packs)
    else
      {:error, :not_shareable} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "The requested instance does not support sharing emoji packs"})
    end
  end

  def index(conn, params) do
    emoji_path =
      [:instance, :static_dir]
      |> Pleroma.Config.get!()
      |> Path.join("emoji")

    with {:ok, packs, count} <- Pack.list_local(page: params.page, page_size: params.page_size) do
      json(conn, %{packs: packs, count: count})
    else
      {:error, :create_dir, e} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to create the emoji pack directory at #{emoji_path}: #{e}"})

      {:error, :ls, e} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: "Failed to get the contents of the emoji pack directory at #{emoji_path}: #{e}"
        })
    end
  end

  def show(conn, %{name: name, page: page, page_size: page_size}) do
    name = String.trim(name)

    with {:ok, pack} <- Pack.show(name: name, page: page, page_size: page_size) do
      json(conn, pack)
    else
      {:error, :enoent} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Pack #{name} does not exist"})

      {:error, :empty_values} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "pack name cannot be empty"})

      {:error, error} ->
        error_message =
          add_posix_error(
            "Failed to get the contents of the `#{name}` pack.",
            error
          )

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: error_message})
    end
  end

  def archive(conn, %{name: name}) do
    with {:ok, archive} <- Pack.get_archive(name) do
      send_download(conn, {:binary, archive}, filename: "#{name}.zip")
    else
      {:error, :cant_download} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error:
            "Pack #{name} cannot be downloaded from this instance, either pack sharing was disabled for this pack or some files are missing"
        })

      {:error, :enoent} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Pack #{name} does not exist"})
    end
  end

  def download(%{body_params: %{url: url, name: name} = params} = conn, _) do
    with {:ok, _pack} <- Pack.download(name, url, params[:as]) do
      json(conn, "ok")
    else
      {:error, :not_shareable} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "The requested instance does not support sharing emoji packs"})

      {:error, :invalid_checksum} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "SHA256 for the pack doesn't match the one sent by the server"})

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: error})
    end
  end

  def create(conn, %{name: name}) do
    name = String.trim(name)

    with {:ok, _pack} <- Pack.create(name) do
      json(conn, "ok")
    else
      {:error, :eexist} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "A pack named \"#{name}\" already exists"})

      {:error, :empty_values} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "pack name cannot be empty"})

      {:error, error} ->
        error_message =
          add_posix_error(
            "Unexpected error occurred while creating pack.",
            error
          )

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: error_message})
    end
  end

  def delete(conn, %{name: name}) do
    name = String.trim(name)

    with {:ok, deleted} when deleted != [] <- Pack.delete(name) do
      json(conn, "ok")
    else
      {:ok, []} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Pack #{name} does not exist"})

      {:error, :empty_values} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "pack name cannot be empty"})

      {:error, error, _} ->
        error_message = add_posix_error("Couldn't delete the `#{name}` pack", error)

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: error_message})
    end
  end

  def update(%{body_params: %{metadata: metadata}} = conn, %{name: name}) do
    with {:ok, pack} <- Pack.update_metadata(name, metadata) do
      json(conn, pack.pack)
    else
      {:error, :incomplete} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "The fallback archive does not have all files specified in pack.json"})

      {:error, error} ->
        error_message =
          add_posix_error(
            "Unexpected error occurred while updating pack metadata.",
            error
          )

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: error_message})
    end
  end

  def import_from_filesystem(conn, _params) do
    with {:ok, names} <- Pack.import_from_filesystem() do
      json(conn, names)
    else
      {:error, :no_read_write} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Error: emoji pack directory must be writable"})

      {:error, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Error accessing emoji pack directory"})
    end
  end

  defp add_posix_error(msg, error) do
    [msg, Pleroma.Utils.posix_error_message(error)]
    |> Enum.join(" ")
    |> String.trim()
  end
end
