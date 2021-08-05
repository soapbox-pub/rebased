# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Object.Fetcher do
  alias Pleroma.HTTP
  alias Pleroma.Maps
  alias Pleroma.Object
  alias Pleroma.Object.Containment
  alias Pleroma.Repo
  alias Pleroma.Signature
  alias Pleroma.Web.ActivityPub.InternalFetchActor
  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.Federator

  require Logger
  require Pleroma.Constants

  defp touch_changeset(changeset) do
    updated_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)

    Ecto.Changeset.put_change(changeset, :updated_at, updated_at)
  end

  defp maybe_reinject_internal_fields(%{data: %{} = old_data}, new_data) do
    internal_fields = Map.take(old_data, Pleroma.Constants.object_internal_fields())

    Map.merge(new_data, internal_fields)
  end

  defp maybe_reinject_internal_fields(_, new_data), do: new_data

  @spec reinject_object(struct(), map()) :: {:ok, Object.t()} | {:error, any()}
  defp reinject_object(%Object{data: %{"type" => "Question"}} = object, new_data) do
    Logger.debug("Reinjecting object #{new_data["id"]}")

    with data <- maybe_reinject_internal_fields(object, new_data),
         {:ok, data, _} <- ObjectValidator.validate(data, %{}),
         changeset <- Object.change(object, %{data: data}),
         changeset <- touch_changeset(changeset),
         {:ok, object} <- Repo.insert_or_update(changeset),
         {:ok, object} <- Object.set_cache(object) do
      {:ok, object}
    else
      e ->
        Logger.error("Error while processing object: #{inspect(e)}")
        {:error, e}
    end
  end

  defp reinject_object(%Object{} = object, new_data) do
    Logger.debug("Reinjecting object #{new_data["id"]}")

    with new_data <- Transmogrifier.fix_object(new_data),
         data <- maybe_reinject_internal_fields(object, new_data),
         changeset <- Object.change(object, %{data: data}),
         changeset <- touch_changeset(changeset),
         {:ok, object} <- Repo.insert_or_update(changeset),
         {:ok, object} <- Object.set_cache(object) do
      {:ok, object}
    else
      e ->
        Logger.error("Error while processing object: #{inspect(e)}")
        {:error, e}
    end
  end

  def refetch_object(%Object{data: %{"id" => id}} = object) do
    with {:local, false} <- {:local, Object.local?(object)},
         {:ok, new_data} <- fetch_and_contain_remote_object_from_id(id),
         {:ok, object} <- reinject_object(object, new_data) do
      {:ok, object}
    else
      {:local, true} -> {:ok, object}
      e -> {:error, e}
    end
  end

  # Note: will create a Create activity, which we need internally at the moment.
  def fetch_object_from_id(id, options \\ []) do
    with {_, nil} <- {:fetch_object, Object.get_cached_by_ap_id(id)},
         {_, true} <- {:allowed_depth, Federator.allowed_thread_distance?(options[:depth])},
         {_, {:ok, data}} <- {:fetch, fetch_and_contain_remote_object_from_id(id)},
         {_, nil} <- {:normalize, Object.normalize(data, fetch: false)},
         params <- prepare_activity_params(data),
         {_, :ok} <- {:containment, Containment.contain_origin(id, params)},
         {_, {:ok, activity}} <-
           {:transmogrifier, Transmogrifier.handle_incoming(params, options)},
         {_, _data, %Object{} = object} <-
           {:object, data, Object.normalize(activity, fetch: false)} do
      {:ok, object}
    else
      {:allowed_depth, false} ->
        {:error, "Max thread distance exceeded."}

      {:containment, _} ->
        {:error, "Object containment failed."}

      {:transmogrifier, {:error, {:reject, e}}} ->
        {:reject, e}

      {:transmogrifier, {:reject, e}} ->
        {:reject, e}

      {:transmogrifier, _} = e ->
        {:error, e}

      {:object, data, nil} ->
        reinject_object(%Object{}, data)

      {:normalize, object = %Object{}} ->
        {:ok, object}

      {:fetch_object, %Object{} = object} ->
        {:ok, object}

      {:fetch, {:error, error}} ->
        {:error, error}

      e ->
        e
    end
  end

  defp prepare_activity_params(data) do
    %{
      "type" => "Create",
      # Should we seriously keep this attributedTo thing?
      "actor" => data["actor"] || data["attributedTo"],
      "object" => data
    }
    |> Maps.put_if_present("to", data["to"])
    |> Maps.put_if_present("cc", data["cc"])
    |> Maps.put_if_present("bto", data["bto"])
    |> Maps.put_if_present("bcc", data["bcc"])
  end

  def fetch_object_from_id!(id, options \\ []) do
    with {:ok, object} <- fetch_object_from_id(id, options) do
      object
    else
      {:error, %Tesla.Mock.Error{}} ->
        nil

      {:error, "Object has been deleted"} ->
        nil

      {:reject, reason} ->
        Logger.info("Rejected #{id} while fetching: #{inspect(reason)}")
        nil

      e ->
        Logger.error("Error while fetching #{id}: #{inspect(e)}")
        nil
    end
  end

  defp make_signature(id, date) do
    uri = URI.parse(id)

    signature =
      InternalFetchActor.get_actor()
      |> Signature.sign(%{
        "(request-target)": "get #{uri.path}",
        host: uri.host,
        date: date
      })

    {"signature", signature}
  end

  defp sign_fetch(headers, id, date) do
    if Pleroma.Config.get([:activitypub, :sign_object_fetches]) do
      [make_signature(id, date) | headers]
    else
      headers
    end
  end

  defp maybe_date_fetch(headers, date) do
    if Pleroma.Config.get([:activitypub, :sign_object_fetches]) do
      [{"date", date} | headers]
    else
      headers
    end
  end

  def fetch_and_contain_remote_object_from_id(id)

  def fetch_and_contain_remote_object_from_id(%{"id" => id}),
    do: fetch_and_contain_remote_object_from_id(id)

  def fetch_and_contain_remote_object_from_id(id) when is_binary(id) do
    Logger.debug("Fetching object #{id} via AP")

    with {:scheme, true} <- {:scheme, String.starts_with?(id, "http")},
         {:ok, body} <- get_object(id),
         {:ok, data} <- safe_json_decode(body),
         :ok <- Containment.contain_origin_from_id(id, data) do
      {:ok, data}
    else
      {:scheme, _} ->
        {:error, "Unsupported URI scheme"}

      {:error, e} ->
        {:error, e}

      e ->
        {:error, e}
    end
  end

  def fetch_and_contain_remote_object_from_id(_id),
    do: {:error, "id must be a string"}

  defp get_object(id) do
    date = Pleroma.Signature.signed_date()

    headers =
      [{"accept", "application/activity+json"}]
      |> maybe_date_fetch(date)
      |> sign_fetch(id, date)

    case HTTP.get(id, headers) do
      {:ok, %{body: body, status: code, headers: headers}} when code in 200..299 ->
        case List.keyfind(headers, "content-type", 0) do
          {_, content_type} ->
            case Plug.Conn.Utils.media_type(content_type) do
              {:ok, "application", "activity+json", _} ->
                {:ok, body}

              {:ok, "application", "ld+json",
               %{"profile" => "https://www.w3.org/ns/activitystreams"}} ->
                {:ok, body}

              _ ->
                {:error, {:content_type, content_type}}
            end

          _ ->
            {:error, {:content_type, nil}}
        end

      {:ok, %{status: code}} when code in [404, 410] ->
        {:error, "Object has been deleted"}

      {:error, e} ->
        {:error, e}

      e ->
        {:error, e}
    end
  end

  defp safe_json_decode(nil), do: {:ok, nil}
  defp safe_json_decode(json), do: Jason.decode(json)
end
