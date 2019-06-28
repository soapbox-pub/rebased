defmodule Pleroma.Object.Fetcher do
  alias Pleroma.HTTP
  alias Pleroma.Object
  alias Pleroma.Object.Containment
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.OStatus

  require Logger

  defp reinject_object(data) do
    Logger.debug("Reinjecting object #{data["id"]}")

    with data <- Transmogrifier.fix_object(data),
         {:ok, object} <- Object.create(data) do
      {:ok, object}
    else
      e ->
        Logger.error("Error while processing object: #{inspect(e)}")
        {:error, e}
    end
  end

  # TODO:
  # This will create a Create activity, which we need internally at the moment.
  def fetch_object_from_id(id) do
    if object = Object.get_cached_by_ap_id(id) do
      {:ok, object}
    else
      Logger.info("Fetching #{id} via AP")

      with {:ok, data} <- fetch_and_contain_remote_object_from_id(id),
           nil <- Object.normalize(data, false),
           params <- %{
             "type" => "Create",
             "to" => data["to"],
             "cc" => data["cc"],
             "actor" => data["actor"] || data["attributedTo"],
             "object" => data
           },
           :ok <- Containment.contain_origin(id, params),
           {:ok, activity} <- Transmogrifier.handle_incoming(params),
           {:object, _data, %Object{} = object} <-
             {:object, data, Object.normalize(activity, false)} do
        {:ok, object}
      else
        {:error, {:reject, nil}} ->
          {:reject, nil}

        {:object, data, nil} ->
          reinject_object(data)

        object = %Object{} ->
          {:ok, object}

        _e ->
          Logger.info("Couldn't get object via AP, trying out OStatus fetching...")

          case OStatus.fetch_activity_from_url(id) do
            {:ok, [activity | _]} -> {:ok, Object.normalize(activity, false)}
            e -> e
          end
      end
    end
  end

  def fetch_object_from_id!(id) do
    with {:ok, object} <- fetch_object_from_id(id) do
      object
    else
      _e ->
        nil
    end
  end

  def fetch_and_contain_remote_object_from_id(id) do
    Logger.info("Fetching object #{id} via AP")

    with true <- String.starts_with?(id, "http"),
         {:ok, %{body: body, status: code}} when code in 200..299 <-
           HTTP.get(
             id,
             [{:Accept, "application/activity+json"}]
           ),
         {:ok, data} <- Jason.decode(body),
         :ok <- Containment.contain_origin_from_id(id, data) do
      {:ok, data}
    else
      {:ok, %{status: code}} when code in [404, 410] ->
        {:error, "Object has been deleted"}

      e ->
        {:error, e}
    end
  end
end
