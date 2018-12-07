defmodule Pleroma.Web.Push do
  use GenServer

  alias Pleroma.{Repo, User}
  alias Pleroma.Web.Push.Subscription

  require Logger
  import Ecto.Query

  @types ["Create", "Follow", "Announce", "Like"]

  @gcm_api_key nil

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    case Application.get_env(:web_push_encryption, :vapid_details) do
      nil ->
        Logger.warn(
          "VAPID key pair is not found. Please, add VAPID configuration to config. Run `mix web_push.gen.keypair` mix task to create a key pair"
        )

        :ignore

      _ ->
        {:ok, %{}}
    end
  end

  def send(notification) do
    if Application.get_env(:web_push_encryption, :vapid_details) do
      GenServer.cast(Pleroma.Web.Push, {:send, notification})
    end
  end

  def handle_cast(
        {:send, %{activity: %{data: %{"type" => type}}, user_id: user_id} = notification},
        state
      )
      when type in @types do
    actor = User.get_cached_by_ap_id(notification.activity.data["actor"])

    Subscription
    |> where(user_id: ^user_id)
    |> preload(:token)
    |> Repo.all()
    |> Enum.each(fn record ->
      subscription = %{
        keys: %{
          p256dh: record.key_p256dh,
          auth: record.key_auth
        },
        endpoint: record.endpoint
      }

      body =
        Jason.encode!(%{
          title: format_title(notification),
          body: format_body(notification, actor),
          notification_id: notification.id,
          icon: User.avatar_url(actor),
          preferred_locale: "en",
          access_token: record.token.token
        })

      case WebPushEncryption.send_web_push(body, subscription, @gcm_api_key) do
        {:ok, %{status_code: code}} when 400 <= code and code < 500 ->
          Logger.debug("Removing subscription record")
          Repo.delete!(record)
          :ok

        {:ok, %{status_code: code}} when 200 <= code and code < 300 ->
          :ok

        {:ok, %{status_code: code}} ->
          Logger.error("Web Push Nonification failed with code: #{code}")
          :error

        _ ->
          Logger.error("Web Push Nonification failed with unknown error")
          :error
      end
    end)

    {:noreply, state}
  end

  def handle_cast({:send, _}, state) do
    Logger.warn("Unknown notification type")
    {:noreply, state}
  end

  defp format_title(%{activity: %{data: %{"type" => type}}}) do
    case type do
      "Create" -> "New Mention"
      "Follow" -> "New Follower"
      "Announce" -> "New Repeat"
      "Like" -> "New Favorite"
    end
  end

  defp format_body(%{activity: %{data: %{"type" => type}}}, actor) do
    case type do
      "Create" -> "@#{actor.nickname} has mentiond you"
      "Follow" -> "@#{actor.nickname} has followed you"
      "Announce" -> "@#{actor.nickname} has repeated your post"
      "Like" -> "@#{actor.nickname} has favorited your post"
    end
  end
end
