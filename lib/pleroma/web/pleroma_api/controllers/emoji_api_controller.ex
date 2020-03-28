defmodule Pleroma.Web.PleromaAPI.EmojiAPIController do
  use Pleroma.Web, :controller

  alias Pleroma.Emoji.Pack

  plug(
    Pleroma.Plugs.OAuthScopesPlug,
    %{scopes: ["write"], admin: true}
    when action in [
           :create,
           :delete,
           :download_from,
           :import_from_fs,
           :update_file,
           :update_metadata
         ]
  )

  plug(
    :skip_plug,
    [Pleroma.Plugs.OAuthScopesPlug, Pleroma.Plugs.ExpectPublicOrAuthenticatedCheckPlug]
    when action in [:download_shared, :list_packs, :list_from]
  )

  @doc """
  Lists packs from the remote instance.

  Since JS cannot ask remote instances for their packs due to CPS, it has to
  be done by the server
  """
  def list_from(conn, %{"instance_address" => address}) do
    with {:ok, packs} <- Pack.list_remote_packs(address) do
      json(conn, packs)
    else
      {:shareable, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "The requested instance does not support sharing emoji packs"})
    end
  end

  @doc """
  Lists the packs available on the instance as JSON.

  The information is public and does not require authentication. The format is
  a map of "pack directory name" to pack.json contents.
  """
  def list_packs(conn, _params) do
    emoji_path =
      Path.join(
        Pleroma.Config.get!([:instance, :static_dir]),
        "emoji"
      )

    with {:ok, packs} <- Pack.list_local_packs() do
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

  @doc """
  An endpoint for other instances (via admin UI) or users (via browser)
  to download packs that the instance shares.
  """
  def download_shared(conn, %{"name" => name}) do
    with {:ok, archive} <- Pack.download(name) do
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

  @doc """
  An admin endpoint to request downloading and storing a pack named `pack_name` from the instance
  `instance_address`.

  If the requested instance's admin chose to share the pack, it will be downloaded
  from that instance, otherwise it will be downloaded from the fallback source, if there is one.
  """
  def download_from(conn, %{"instance_address" => address, "pack_name" => name} = params) do
    with :ok <- Pack.download_from_source(name, address, params["as"]) do
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

  @doc """
  Creates an empty pack named `name` which then can be updated via the admin UI.
  """
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

  @doc """
  Deletes the pack `name` and all it's files.
  """
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

  @doc """
  An endpoint to update `pack_names`'s metadata.

  `new_data` is the new metadata for the pack, that will replace the old metadata.
  """
  def update_metadata(conn, %{"pack_name" => name, "new_data" => new_data}) do
    with {:ok, pack} <- Pack.update_metadata(name, new_data) do
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

  @doc """
  Updates a file in a pack.

  Updating can mean three things:

  - `add` adds an emoji named `shortcode` to the pack `pack_name`,
    that means that the emoji file needs to be uploaded with the request
    (thus requiring it to be a multipart request) and be named `file`.
    There can also be an optional `filename` that will be the new emoji file name
    (if it's not there, the name will be taken from the uploaded file).
  - `update` changes emoji shortcode (from `shortcode` to `new_shortcode` or moves the file
    (from the current filename to `new_filename`)
  - `remove` removes the emoji named `shortcode` and it's associated file
  """

  # Add
  def update_file(
        conn,
        %{"pack_name" => pack_name, "action" => "add"} = params
      ) do
    filename = params["filename"] || get_filename(params["file"])
    shortcode = params["shortcode"] || Path.basename(filename, Path.extname(filename))

    with {:ok, pack} <- Pack.add_file(pack_name, shortcode, filename, params["file"]) do
      json(conn, pack.files)
    else
      {:exists, _} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "An emoji with the \"#{shortcode}\" shortcode already exists"})

      {:loaded, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "pack \"#{pack_name}\" is not found"})

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

  # Remove
  def update_file(conn, %{
        "pack_name" => pack_name,
        "action" => "remove",
        "shortcode" => shortcode
      }) do
    with {:ok, pack} <- Pack.remove_file(pack_name, shortcode) do
      json(conn, pack.files)
    else
      {:exists, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Emoji \"#{shortcode}\" does not exist"})

      {:loaded, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "pack \"#{pack_name}\" is not found"})

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

  # Update
  def update_file(
        conn,
        %{"pack_name" => name, "action" => "update", "shortcode" => shortcode} = params
      ) do
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

  def update_file(conn, %{"action" => action}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Unknown action: #{action}"})
  end

  @doc """
  Imports emoji from the filesystem.

  Importing means checking all the directories in the
  `$instance_static/emoji/` for directories which do not have
  `pack.json`. If one has an emoji.txt file, that file will be used
  to create a `pack.json` file with it's contents. If the directory has
  neither, all the files with specific configured extenstions will be
  assumed to be emojis and stored in the new `pack.json` file.
  """

  def import_from_fs(conn, _params) do
    with {:ok, names} <- Pack.import_from_filesystem() do
      json(conn, names)
    else
      {:error, :not_writable} ->
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
