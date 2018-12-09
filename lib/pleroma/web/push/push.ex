defmodule Pleroma.Web.Push do
  use GenServer

  alias Pleroma.{Repo, User}
  alias Pleroma.Web.Push.Subscription

  require Logger
  import Ecto.Query

  @types ["Create", "Follow", "Announce", "Like"]

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def vapid_config() do
    Application.get_env(:web_push_encryption, :vapid_details, [])
  end

  def enabled() do
    case vapid_config() do
      [] -> false
      list when is_list(list) -> true
      _ -> false
    end
  end

  def send(notification) do
    if enabled() do
      GenServer.cast(Pleroma.Web.Push, {:send, notification})
    end
  end

  def init(:ok) do
    if enabled() do
      Logger.warn("""
      VAPID key pair is not found. If you wish to enabled web push, please run

          mix web_push.gen.keypair

      and add the resulting output to your configuration file.
      """)

      :ignore
    else
      {:ok, nil}
    end
  end

  def handle_cast(
        {:send, %{activity: %{data: %{"type" => type}}, user_id: user_id} = notification},
        state
      )
      when type in @types do
    actor = User.get_cached_by_ap_id(notification.activity.data["actor"])

    type = format_type(notification)

    Subscription
    |> where(user_id: ^user_id)
    |> preload(:token)
    |> Repo.all()
    |> Enum.filter(fn subscription ->
      get_in(subscription.data, ["alerts", type]) || false
    end)
    |> Enum.each(fn subscription ->
      sub = %{
        keys: %{
          p256dh: subscription.key_p256dh,
          auth: subscription.key_auth
        },
        endpoint: subscription.endpoint
      }

      body =
        Jason.encode!(%{
          title: format_title(notification),
          access_token: subscription.token.token,
          body: format_body(notification, actor),
          notification_id: notification.id,
          notification_type: type,
          icon: User.avatar_url(actor),
          preferred_locale: "en"
        })

      case WebPushEncryption.send_web_push(
             body,
             sub,
             Application.get_env(:web_push_encryption, :gcm_api_key)
           ) do
        {:ok, %{status_code: code}} when 400 <= code and code < 500 ->
          Logger.debug("Removing subscription record")
          Repo.delete!(subscription)
          :ok

        {:ok, %{status_code: code}} when 200 <= code and code < 300 ->
          :ok

        {:ok, %{status_code: code}} ->
          Logger.error("Web Push Notification failed with code: #{code}")
          :error

        _ ->
          Logger.error("Web Push Notification failed with unknown error")
          :error
      end
    end)

    {:noreply, state}
  end

  def handle_cast({:send, _}, state) do
    Logger.warn("Unknown notification type")
    {:noreply, state}
  end

  # https://github.com/tootsuite/mastodon/blob/master/app/models/notification.rb#L19
  defp format_type(%{activity: %{data: %{"type" => type}}}) do
    case type do
      "Create" -> "mention"
      "Follow" -> "follow"
      "Announce" -> "reblog"
      "Like" -> "favourite"
    end
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
      "Create" -> "@#{actor.nickname} has mentioned you"
      "Follow" -> "@#{actor.nickname} has followed you"
      "Announce" -> "@#{actor.nickname} has repeated your post"
      "Like" -> "@#{actor.nickname} has favorited your post"
    end
  end
end
