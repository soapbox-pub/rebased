defmodule Pleroma.Object.Fetcher do
  alias Pleroma.{Object, Repo}
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
           nil <- Object.normalize(data),
           params <- %{
             "type" => "Create",
             "to" => data["to"],
             "cc" => data["cc"],
             "actor" => data["actor"] || data["attributedTo"],
             "object" => data
           },
           :ok <- Containment.contain_origin(id, params),
           {:ok, activity} <- Transmogrifier.handle_incoming(params) do
        {:ok, Object.normalize(activity.data["object"])}
      else
        {:error, {:reject, nil}} ->
          {:reject, nil}

        object = %Object{} ->
          {:ok, object}

        _e ->
          Logger.info("Couldn't get object via AP, trying out OStatus fetching...")

          case OStatus.fetch_activity_from_url(id) do
            {:ok, [activity | _]} -> {:ok, Object.normalize(activity.data["object"])}
            e -> e
          end
      end
    end
  end

  def fetch_and_contain_remote_object_from_id(id) do
    Logger.info("Fetching #{id} via AP")

    with true <- String.starts_with?(id, "http"),
         {:ok, %{body: body, status_code: code}} when code in 200..299 <-
           @httpoison.get(
             id,
             [Accept: "application/activity+json"],
             follow_redirect: true,
             timeout: 10000,
             recv_timeout: 20000
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
