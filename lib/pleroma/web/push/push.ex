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
        Logger.error(
          "VAPID key pair is not found. Please, add VAPID configuration to config. Run `mix web_push.gen.keypair` mix task to create a key pair"
        )

        {:error, %{}}

      _ ->
        {:ok, %{}}
    end
  end

  def send(notification) do
    GenServer.cast(Pleroma.Web.Push, {:send, notification})
  end

  def handle_cast(
        {:send, %{activity: %{data: %{"type" => type}}, user_id: user_id} = notification},
        state
      )
      when type in @types do
    actor = User.get_cached_by_ap_id(notification.activity.data["actor"])
    body = notification |> format(actor) |> Jason.encode!()

    Subscription
    |> where(user_id: ^user_id)
    |> Repo.all()
    |> Enum.each(fn record ->
      subscription = %{
        keys: %{
          p256dh: record.key_p256dh,
          auth: record.key_auth
        },
        endpoint: record.endpoint
      }

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

        data ->
          Logger.error("Web Push Nonification failed with unknown error")
          IO.inspect(data)
          :error
      end
    end)

    {:noreply, state}
  end

  def handle_cast({:send, _}, state) do
    Logger.warn("Unknown notification type")
    {:noreply, state}
  end

  def format(%{activity: %{data: %{"type" => "Create"}}}, actor) do
    %{
      title: "New Mention",
      body: "@#{actor.nickname} has mentiond you",
      icon: get_avatar_url(actor)
    }
  end

  def format(%{activity: %{data: %{"type" => "Follow"}}}, actor) do
    %{
      title: "New Follower",
      body: "@#{actor.nickname} has followed you",
      icon: get_avatar_url(actor)
    }
  end

  def format(%{activity: %{data: %{"type" => "Announce"}}}, actor) do
    %{
      title: "New Announce",
      body: "@#{actor.nickname} has announced your post",
      icon: get_avatar_url(actor)
    }
  end

  def format(%{activity: %{data: %{"type" => "Like"}}}, actor) do
    %{
      title: "New Like",
      body: "@#{actor.nickname} has liked your post",
      icon: get_avatar_url(actor)
    }
  end

  def get_avatar_url(%{avatar: %{"type" => "Image", "url" => urls}}) do
    case List.first(urls) do
      %{"href" => url} -> url
      _ -> get_avatar_url(nil)
    end
  end

  def get_avatar_url(_) do
    Pleroma.Web.Endpoint.static_url() <> "/images/avi.png"
  end
end
