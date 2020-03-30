defmodule Pleroma.Web.PleromaAPI.EmojiAPIController do
  use Pleroma.Web, :controller

  alias Pleroma.Emoji.Pack

  plug(
    Pleroma.Plugs.OAuthScopesPlug,
    %{scopes: ["write"], admin: true}
    when action in [
           :import,
           :remote,
           :download,
           :create,
           :update,
           :delete,
           :add_file,
           :update_file,
           :delete_file
         ]
  )

  plug(
    :skip_plug,
    [Pleroma.Plugs.OAuthScopesPlug, Pleroma.Plugs.ExpectPublicOrAuthenticatedCheckPlug]
    when action in [:download_shared, :list_packs, :list_from]
  )

  def remote(conn, %{"url" => url}) do
    with {:ok, packs} <- Pack.list_remote(url) do
      json(conn, packs)
    else
      {:shareable, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "The requested instance does not support sharing emoji packs"})
    end
  end

  def list(conn, _params) do
    emoji_path =
      Path.join(
        Pleroma.Config.get!([:instance, :static_dir]),
        "emoji"
      )

    with {:ok, packs} <- Pack.list_local() do
      json(conn, packs)
    else
      {:create_dir, {:error, e}} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to create the emoji pack directory at #{emoji_path}: #{e}"})

      {:ls, {:error, e}} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: "Failed to get the contents of the emoji pack directory at #{emoji_path}: #{e}"
        })
    end
  end

  def show(conn, %{"name" => name}) do
    name = String.trim(name)

    with {:ok, pack} <- Pack.show(name) do
      json(conn, pack)
    else
      {:loaded, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Pack #{name} does not exist"})

      {:error, :empty_values} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "pack name cannot be empty"})
    end
  end

  def archive(conn, %{"name" => name}) do
    with {:ok, archive} <- Pack.get_archive(name) do
      send_download(conn, {:binary, archive}, filename: "#{name}.zip")
    else
      {:can_download?, _} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error:
            "Pack #{name} cannot be downloaded from this instance, either pack sharing was disabled for this pack or some files are missing"
        })

      {:exists?, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Pack #{name} does not exist"})
    end
  end

  def download(conn, %{"url" => url, "name" => name} = params) do
    with :ok <- Pack.download(name, url, params["as"]) do
      json(conn, "ok")
    else
      {:shareable, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "The requested instance does not support sharing emoji packs"})

      {:checksum, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "SHA256 for the pack doesn't match the one sent by the server"})

      {:error, e} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: e})
    end
  end

  def create(conn, %{"name" => name}) do
    name = String.trim(name)

    with :ok <- Pack.create(name) do
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

      {:error, _} ->
        render_error(
          conn,
          :internal_server_error,
          "Unexpected error occurred while creating pack."
        )
    end
  end

  def delete(conn, %{"name" => name}) do
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

      {:error, _, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Couldn't delete the pack #{name}"})
    end
  end

  def update(conn, %{"name" => name, "metadata" => metadata}) do
    with {:ok, pack} <- Pack.update_metadata(name, metadata) do
      json(conn, pack.pack)
    else
      {:has_all_files?, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "The fallback archive does not have all files specified in pack.json"})

      {:error, _} ->
        render_error(
          conn,
          :internal_server_error,
          "Unexpected error occurred while updating pack metadata."
        )
    end
  end

  def add_file(conn, %{"name" => name} = params) do
    filename = params["filename"] || get_filename(params["file"])
    shortcode = params["shortcode"] || Path.basename(filename, Path.extname(filename))

    with {:ok, pack} <- Pack.add_file(name, shortcode, filename, params["file"]) do
      json(conn, pack.files)
    else
      {:exists, _} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "An emoji with the \"#{shortcode}\" shortcode already exists"})

      {:loaded, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "pack \"#{name}\" is not found"})

      {:error, :empty_values} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "pack name, shortcode or filename cannot be empty"})

      {:error, _} ->
        render_error(
          conn,
          :internal_server_error,
          "Unexpected error occurred while adding file to pack."
        )
    end
  end

  def update_file(conn, %{"name" => name, "shortcode" => shortcode} = params) do
    new_shortcode = params["new_shortcode"]
    new_filename = params["new_filename"]
    force = params["force"] == true

    with {:ok, pack} <- Pack.update_file(name, shortcode, new_shortcode, new_filename, force) do
      json(conn, pack.files)
    else
      {:exists, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Emoji \"#{shortcode}\" does not exist"})

      {:not_used, _} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error:
            "New shortcode \"#{new_shortcode}\" is already used. If you want to override emoji use 'force' option"
        })

      {:loaded, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "pack \"#{name}\" is not found"})

      {:error, :empty_values} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "new_shortcode or new_filename cannot be empty"})

      {:error, _} ->
        render_error(
          conn,
          :internal_server_error,
          "Unexpected error occurred while updating file in pack."
        )
    end
  end

  def delete_file(conn, %{"name" => name, "shortcode" => shortcode}) do
    with {:ok, pack} <- Pack.delete_file(name, shortcode) do
      json(conn, pack.files)
    else
      {:exists, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Emoji \"#{shortcode}\" does not exist"})

      {:loaded, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "pack \"#{name}\" is not found"})

      {:error, :empty_values} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "pack name or shortcode cannot be empty"})

      {:error, _} ->
        render_error(
          conn,
          :internal_server_error,
          "Unexpected error occurred while removing file from pack."
        )
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

  defp get_filename(%Plug.Upload{filename: filename}), do: filename
  defp get_filename(url) when is_binary(url), do: Path.basename(url)
end
