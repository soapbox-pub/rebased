defmodule Pleroma.Web.PleromaAPI.EmojiAPIController do
  use Pleroma.Web, :controller

  alias Pleroma.Emoji.Pack

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    Pleroma.Plugs.OAuthScopesPlug,
    %{scopes: ["write"], admin: true}
    when action in [
           :import_from_filesystem,
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

  @skip_plugs [Pleroma.Plugs.OAuthScopesPlug, Pleroma.Plugs.ExpectPublicOrAuthenticatedCheckPlug]
  plug(:skip_plug, @skip_plugs when action in [:archive, :show, :list])

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.PleromaEmojiOperation

  def remote(conn, %{url: url}) do
    with {:ok, packs} <- Pack.list_remote(url) do
      json(conn, packs)
    else
      {:error, :not_shareable} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "The requested instance does not support sharing emoji packs"})
    end
  end

  def index(conn, _params) do
    emoji_path =
      [:instance, :static_dir]
      |> Pleroma.Config.get!()
      |> Path.join("emoji")

    with {:ok, packs} <- Pack.list_local() do
      json(conn, packs)
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

  def show(conn, %{name: name}) do
    name = String.trim(name)

    with {:ok, pack} <- Pack.show(name) do
      json(conn, pack)
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Pack #{name} does not exist"})

      {:error, :empty_values} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "pack name cannot be empty"})
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

      {:error, :not_found} ->
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

      {:error, :imvalid_checksum} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "SHA256 for the pack doesn't match the one sent by the server"})

      {:error, e} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: e})
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

      {:error, _} ->
        render_error(
          conn,
          :internal_server_error,
          "Unexpected error occurred while creating pack."
        )
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

      {:error, _, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Couldn't delete the pack #{name}"})
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

      {:error, _} ->
        render_error(
          conn,
          :internal_server_error,
          "Unexpected error occurred while updating pack metadata."
        )
    end
  end

  def add_file(%{body_params: params} = conn, %{name: name}) do
    filename = params[:filename] || get_filename(params[:file])
    shortcode = params[:shortcode] || Path.basename(filename, Path.extname(filename))

    with {:ok, pack} <- Pack.add_file(name, shortcode, filename, params[:file]) do
      json(conn, pack.files)
    else
      {:error, :already_exists} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "An emoji with the \"#{shortcode}\" shortcode already exists"})

      {:error, :not_found} ->
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

  def update_file(%{body_params: %{shortcode: shortcode} = params} = conn, %{name: name}) do
    new_shortcode = params[:new_shortcode]
    new_filename = params[:new_filename]
    force = params[:force]

    with {:ok, pack} <- Pack.update_file(name, shortcode, new_shortcode, new_filename, force) do
      json(conn, pack.files)
    else
      {:error, :doesnt_exist} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Emoji \"#{shortcode}\" does not exist"})

      {:error, :already_exists} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error:
            "New shortcode \"#{new_shortcode}\" is already used. If you want to override emoji use 'force' option"
        })

      {:error, :not_found} ->
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

  def delete_file(conn, %{name: name, shortcode: shortcode}) do
    with {:ok, pack} <- Pack.delete_file(name, shortcode) do
      json(conn, pack.files)
    else
      {:error, :doesnt_exist} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Emoji \"#{shortcode}\" does not exist"})

      {:error, :not_found} ->
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
