defmodule Pleroma.Object.Fetcher do
  alias Pleroma.Object
  alias Pleroma.Object.Containment
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.OStatus

  require Logger

  @httpoison Application.get_env(:pleroma, :httpoison)

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
           {:ok, activity} <- Transmogrifier.handle_incoming(params) do
        {:ok, Object.normalize(activity, false)}
      else
        {:error, {:reject, nil}} ->
          {:reject, nil}

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
           @httpoison.get(
             id,
             [{:Accept, "application/activity+json"}]
           ),
         {:ok, data} <- Jason.decode(body),
         :ok <- Containment.contain_origin_from_id(id, data) do
      {:ok, data}
    else
      e ->
        {:error, e}
    end
  end
end
