defmodule Pleroma.Web.PleromaAPI.EmojiFileController do
  use Pleroma.Web, :controller

  alias Pleroma.Emoji.Pack
  alias Pleroma.Web.ApiSpec

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    Pleroma.Plugs.OAuthScopesPlug,
    %{scopes: ["write"], admin: true}
    when action in [
           :create,
           :update,
           :delete
         ]
  )

  defdelegate open_api_operation(action), to: ApiSpec.PleromaEmojiFileOperation

  def create(%{body_params: params} = conn, %{name: pack_name}) do
    filename = params[:filename] || get_filename(params[:file])
    shortcode = params[:shortcode] || Path.basename(filename, Path.extname(filename))

    with {:ok, pack} <- Pack.add_file(pack_name, shortcode, filename, params[:file]) do
      json(conn, pack.files)
    else
      {:error, :already_exists} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "An emoji with the \"#{shortcode}\" shortcode already exists"})

      {:error, :not_found} ->
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

  def update(%{body_params: %{shortcode: shortcode} = params} = conn, %{name: pack_name}) do
    new_shortcode = params[:new_shortcode]
    new_filename = params[:new_filename]
    force = params[:force]

    with {:ok, pack} <- Pack.update_file(pack_name, shortcode, new_shortcode, new_filename, force) do
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
        |> json(%{error: "pack \"#{pack_name}\" is not found"})

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

  def delete(conn, %{name: pack_name, shortcode: shortcode}) do
    with {:ok, pack} <- Pack.delete_file(pack_name, shortcode) do
      json(conn, pack.files)
    else
      {:error, :doesnt_exist} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Emoji \"#{shortcode}\" does not exist"})

      {:error, :not_found} ->
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

  defp get_filename(%Plug.Upload{filename: filename}), do: filename
  defp get_filename(url) when is_binary(url), do: Path.basename(url)
end
