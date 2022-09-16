# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload do
  @moduledoc """
  Manage user uploads

  Options:
  * `:type`: presets for activity type (defaults to Document) and size limits from app configuration
  * `:description`: upload alternative text
  * `:base_url`: override base url
  * `:uploader`: override uploader
  * `:filters`: override filters
  * `:size_limit`: override size limit
  * `:activity_type`: override activity type

  The `%Pleroma.Upload{}` struct: all documented fields are meant to be overwritten in filters:

  * `:id` - the upload id.
  * `:name` - the upload file name.
  * `:path` - the upload path: set at first to `id/name` but can be changed. Keep in mind that the path
    is once created permanent and changing it (especially in uploaders) is probably a bad idea!
  * `:tempfile` - path to the temporary file. Prefer in-place changes on the file rather than changing the
  path as the temporary file is also tracked by `Plug.Upload{}` and automatically deleted once the request is over.
  * `:width` - width of the media in pixels
  * `:height` - height of the media in pixels
  * `:blurhash` - string hash of the image encoded with the blurhash algorithm (https://blurha.sh/)

  Related behaviors:

  * `Pleroma.Uploaders.Uploader`
  * `Pleroma.Upload.Filter`

  """
  alias Ecto.UUID
  alias Pleroma.Config
  alias Pleroma.Maps
  alias Pleroma.Web.ActivityPub.Utils
  require Logger

  @type source ::
          Plug.Upload.t()
          | (data_uri_string :: String.t())
          | {:from_local, name :: String.t(), id :: String.t(), path :: String.t()}
          | map()

  @type option ::
          {:type, :avatar | :banner | :background}
          | {:description, String.t()}
          | {:activity_type, String.t()}
          | {:size_limit, nil | non_neg_integer()}
          | {:uploader, module()}
          | {:filters, [module()]}

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          tempfile: String.t(),
          content_type: String.t(),
          width: integer(),
          height: integer(),
          blurhash: String.t(),
          description: String.t(),
          path: String.t()
        }
  defstruct [
    :id,
    :name,
    :tempfile,
    :content_type,
    :width,
    :height,
    :blurhash,
    :description,
    :path
  ]

  defp get_description(upload) do
    case {upload.description, Pleroma.Config.get([Pleroma.Upload, :default_description])} do
      {description, _} when is_binary(description) -> description
      {_, :filename} -> upload.name
      {_, str} when is_binary(str) -> str
      _ -> ""
    end
  end

  @spec store(source, options :: [option()]) :: {:ok, Map.t()} | {:error, any()}
  @doc "Store a file. If using a `Plug.Upload{}` as the source, be sure to use `Majic.Plug` to ensure its content_type and filename is correct."
  def store(upload, opts \\ []) do
    opts = get_opts(opts)

    with {:ok, upload} <- prepare_upload(upload, opts),
         upload = %__MODULE__{upload | path: upload.path || "#{upload.id}/#{upload.name}"},
         {:ok, upload} <- Pleroma.Upload.Filter.filter(opts.filters, upload),
         description = get_description(upload),
         {_, true} <-
           {:description_limit,
            String.length(description) <= Pleroma.Config.get([:instance, :description_limit])},
         {:ok, url_spec} <- Pleroma.Uploaders.Uploader.put_file(opts.uploader, upload) do
      {:ok,
       %{
         "id" => Utils.generate_object_id(),
         "type" => opts.activity_type,
         "mediaType" => upload.content_type,
         "url" => [
           %{
             "type" => "Link",
             "mediaType" => upload.content_type,
             "href" => url_from_spec(upload, opts.base_url, url_spec)
           }
           |> Maps.put_if_present("width", upload.width)
           |> Maps.put_if_present("height", upload.height)
         ],
         "name" => description
       }
       |> Maps.put_if_present("blurhash", upload.blurhash)}
    else
      {:description_limit, _} ->
        {:error, :description_too_long}

      {:error, error} ->
        Logger.error(
          "#{__MODULE__} store (using #{inspect(opts.uploader)}) failed: #{inspect(error)}"
        )

        {:error, error}
    end
  end

  def char_unescaped?(char) do
    URI.char_unreserved?(char) or char == ?/
  end

  defp get_opts(opts) do
    {size_limit, activity_type} =
      case Keyword.get(opts, :type) do
        :banner ->
          {Pleroma.Config.get!([:instance, :banner_upload_limit]), "Image"}

        :avatar ->
          {Pleroma.Config.get!([:instance, :avatar_upload_limit]), "Image"}

        :background ->
          {Pleroma.Config.get!([:instance, :background_upload_limit]), "Image"}

        _ ->
          {Pleroma.Config.get!([:instance, :upload_limit]), "Document"}
      end

    %{
      activity_type: Keyword.get(opts, :activity_type, activity_type),
      size_limit: Keyword.get(opts, :size_limit, size_limit),
      uploader: Keyword.get(opts, :uploader, Pleroma.Config.get([__MODULE__, :uploader])),
      filters: Keyword.get(opts, :filters, Pleroma.Config.get([__MODULE__, :filters])),
      description: Keyword.get(opts, :description),
      base_url: base_url()
    }
  end

  defp prepare_upload(%Plug.Upload{} = file, opts) do
    with :ok <- check_file_size(file.path, opts.size_limit) do
      {:ok,
       %__MODULE__{
         id: UUID.generate(),
         name: file.filename,
         tempfile: file.path,
         content_type: file.content_type,
         description: opts.description
       }}
    end
  end

  defp prepare_upload(%{img: "data:image/" <> image_data}, opts) do
    parsed = Regex.named_captures(~r/(?<filetype>jpeg|png|gif);base64,(?<data>.*)/, image_data)
    data = Base.decode64!(parsed["data"], ignore: :whitespace)
    hash = Base.encode16(:crypto.hash(:sha256, data), lower: true)

    with :ok <- check_binary_size(data, opts.size_limit),
         tmp_path <- tempfile_for_image(data),
         {:ok, %{mime_type: content_type}} <-
           Majic.perform({:bytes, data}, pool: Pleroma.MajicPool),
         [ext | _] <- MIME.extensions(content_type) do
      {:ok,
       %__MODULE__{
         id: UUID.generate(),
         name: hash <> "." <> ext,
         tempfile: tmp_path,
         content_type: content_type,
         description: opts.description
       }}
    end
  end

  # For Mix.Tasks.MigrateLocalUploads
  defp prepare_upload(%__MODULE__{tempfile: path} = upload, _opts) do
    with {:ok, %{mime_type: content_type}} <- Majic.perform(path, pool: Pleroma.MajicPool) do
      {:ok, %__MODULE__{upload | content_type: content_type}}
    end
  end

  defp check_binary_size(binary, size_limit)
       when is_integer(size_limit) and size_limit > 0 and byte_size(binary) >= size_limit do
    {:error, :file_too_large}
  end

  defp check_binary_size(_, _), do: :ok

  defp check_file_size(path, size_limit) when is_integer(size_limit) and size_limit > 0 do
    with {:ok, %{size: size}} <- File.stat(path),
         true <- size <= size_limit do
      :ok
    else
      false -> {:error, :file_too_large}
      error -> error
    end
  end

  defp check_file_size(_, _), do: :ok

  # Creates a tempfile using the Plug.Upload Genserver which cleans them up
  # automatically.
  defp tempfile_for_image(data) do
    {:ok, tmp_path} = Plug.Upload.random_file("profile_pics")
    {:ok, tmp_file} = File.open(tmp_path, [:write, :raw, :binary])
    IO.binwrite(tmp_file, data)

    tmp_path
  end

  defp url_from_spec(%__MODULE__{name: name}, base_url, {:file, path}) do
    path =
      URI.encode(path, &char_unescaped?/1) <>
        if Pleroma.Config.get([__MODULE__, :link_name], false) do
          "?name=#{URI.encode(name, &char_unescaped?/1)}"
        else
          ""
        end

    [base_url, path]
    |> Path.join()
  end

  defp url_from_spec(_upload, _base_url, {:url, url}), do: url

  def base_url do
    uploader = Config.get([Pleroma.Upload, :uploader])
    upload_base_url = Config.get([Pleroma.Upload, :base_url])
    public_endpoint = Config.get([uploader, :public_endpoint])

    case uploader do
      Pleroma.Uploaders.Local ->
        upload_base_url || Pleroma.Web.Endpoint.url() <> "/media/"

      Pleroma.Uploaders.S3 ->
        bucket = Config.get([Pleroma.Uploaders.S3, :bucket])
        truncated_namespace = Config.get([Pleroma.Uploaders.S3, :truncated_namespace])
        namespace = Config.get([Pleroma.Uploaders.S3, :bucket_namespace])

        bucket_with_namespace =
          cond do
            !is_nil(truncated_namespace) ->
              truncated_namespace

            !is_nil(namespace) ->
              namespace <> ":" <> bucket

            true ->
              bucket
          end

        if public_endpoint do
          Path.join([public_endpoint, bucket_with_namespace])
        else
          Path.join([upload_base_url, bucket_with_namespace])
        end

      _ ->
        public_endpoint || upload_base_url || Pleroma.Web.Endpoint.url() <> "/media/"
    end
  end
end
