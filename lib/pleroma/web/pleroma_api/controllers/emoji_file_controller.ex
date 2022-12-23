# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EmojiFileController do
  use Pleroma.Web, :controller

  alias Pleroma.Emoji.Pack
  alias Pleroma.Web.ApiSpec

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(
    Pleroma.Web.Plugs.OAuthScopesPlug,
    %{scopes: ["admin:write"]}
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

    with {:ok, pack} <- Pack.load_pack(pack_name),
         {:ok, file} <- get_file(params[:file]),
         {:ok, pack} <- Pack.add_file(pack, shortcode, filename, file) do
      json(conn, pack.files)
    else
      {:error, :already_exists} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "An emoji with the \"#{shortcode}\" shortcode already exists"})

      {:error, :empty_values} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "pack name, shortcode or filename cannot be empty"})

      {:error, _} = error ->
        handle_error(conn, error, %{
          pack_name: pack_name,
          message: "Unexpected error occurred while adding file to pack."
        })
    end
  end

  def update(%{body_params: %{shortcode: shortcode} = params} = conn, %{name: pack_name}) do
    new_shortcode = params[:new_shortcode]
    new_filename = params[:new_filename]
    force = params[:force]

    with {:ok, pack} <- Pack.load_pack(pack_name),
         {:ok, pack} <- Pack.update_file(pack, shortcode, new_shortcode, new_filename, force) do
      json(conn, pack.files)
    else
      {:error, :already_exists} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error:
            "New shortcode \"#{new_shortcode}\" is already used. If you want to override emoji use 'force' option"
        })

      {:error, :empty_values} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "new_shortcode or new_filename cannot be empty"})

      {:error, _} = error ->
        handle_error(conn, error, %{
          pack_name: pack_name,
          code: shortcode,
          message: "Unexpected error occurred while updating."
        })
    end
  end

  def delete(conn, %{name: pack_name, shortcode: shortcode}) do
    with {:ok, pack} <- Pack.load_pack(pack_name),
         {:ok, pack} <- Pack.delete_file(pack, shortcode) do
      json(conn, pack.files)
    else
      {:error, :empty_values} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "pack name or shortcode cannot be empty"})

      {:error, _} = error ->
        handle_error(conn, error, %{
          pack_name: pack_name,
          code: shortcode,
          message: "Unexpected error occurred while deleting emoji file."
        })
    end
  end

  defp handle_error(conn, {:error, :doesnt_exist}, %{code: emoji_code}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Emoji \"#{emoji_code}\" does not exist"})
  end

  defp handle_error(conn, {:error, :enoent}, %{pack_name: pack_name}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "pack \"#{pack_name}\" is not found"})
  end

  defp handle_error(conn, {:error, error}, opts) do
    message =
      [
        Map.get(opts, :message, "Unexpected error occurred."),
        Pleroma.Utils.posix_error_message(error)
      ]
      |> Enum.join(" ")
      |> String.trim()

    conn
    |> put_status(:internal_server_error)
    |> json(%{error: message})
  end

  defp get_filename(%Plug.Upload{filename: filename}), do: filename
  defp get_filename(url) when is_binary(url), do: Path.basename(url)

  def get_file(%Plug.Upload{} = file), do: {:ok, file}

  def get_file(url) when is_binary(url) do
    with {:ok, %Tesla.Env{body: body, status: code, headers: headers}}
         when code in 200..299 <- Pleroma.HTTP.get(url) do
      path = Plug.Upload.random_file!("emoji")

      content_type =
        case List.keyfind(headers, "content-type", 0) do
          {"content-type", value} -> value
          nil -> nil
        end

      File.write(path, body)

      {:ok,
       %Plug.Upload{
         filename: Path.basename(url),
         path: path,
         content_type: content_type
       }}
    end
  end
end
