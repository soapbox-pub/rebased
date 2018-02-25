defmodule Pleroma.Web.ActivityPub.Transmogrifier do
  @moduledoc """
  A module to handle coding from internal to wire ActivityPub and back.
  """
  alias Pleroma.User
  alias Pleroma.Object
  alias Pleroma.Activity
  alias Pleroma.Repo
  alias Pleroma.Web.ActivityPub.ActivityPub

  import Ecto.Query

  require Logger

  @doc """
  Modifies an incoming AP object (mastodon format) to our internal format.
  """
  def fix_object(object) do
    object
    |> Map.put("actor", object["attributedTo"])
    |> fix_attachments
    |> fix_context
    |> fix_in_reply_to
  end

  def fix_in_reply_to(%{"inReplyTo" => in_reply_to_id} = object) when not is_nil(in_reply_to_id) do
    case ActivityPub.fetch_object_from_id(object["inReplyToAtomUri"] || in_reply_to_id) do
      {:ok, replied_object} ->
        activity = Activity.get_create_activity_by_object_ap_id(replied_object.data["id"])
        object
        |> Map.put("inReplyTo", replied_object.data["id"])
        |> Map.put("inReplyToAtomUri", object["inReplyToAtomUri"] || in_reply_to_id)
        |> Map.put("inReplyToStatusId", activity.id)
      e ->
        Logger.error("Couldn't fetch #{object["inReplyTo"]} #{inspect(e)}")
        object
    end
  end
  def fix_in_reply_to(object), do: object

  def fix_context(object) do
    object
    |> Map.put("context", object["conversation"])
  end

  def fix_attachments(object) do
    attachments = (object["attachment"] || [])
    |> Enum.map(fn (data) ->
      url = [%{"type" => "Link", "mediaType" => data["mediaType"], "href" => data["url"]}]
      Map.put(data, "url", url)
    end)

    object
    |> Map.put("attachment", attachments)
  end

  # TODO: validate those with a Ecto scheme
  # - tags
  # - emoji
  def handle_incoming(%{"type" => "Create", "object" => %{"type" => "Note"} = object} = data) do
    with nil <- Activity.get_create_activity_by_object_ap_id(object["id"]),
         %User{} = user <- User.get_or_fetch_by_ap_id(data["actor"]) do
      object = fix_object(data["object"])

      params = %{
        to: data["to"],
        object: object,
        actor: user,
        context: data["object"]["conversation"],
        local: false,
        published: data["published"],
        additional: Map.take(data, [
              "cc",
              "id"
            ])
      }


      ActivityPub.create(params)
    else
      %Activity{} = activity -> {:ok, activity}
      _e -> :error
    end
  end

  def handle_incoming(%{"type" => "Follow", "object" => followed, "actor" => follower, "id" => id} = data) do
    with %User{local: true} = followed <- User.get_cached_by_ap_id(followed),
         %User{} = follower <- User.get_or_fetch_by_ap_id(follower),
         {:ok, activity} <- ActivityPub.follow(follower, followed, id, false) do
      ActivityPub.accept(%{to: [follower.ap_id], actor: followed.ap_id, object: data, local: true})
      User.follow(follower, followed)
      {:ok, activity}
    else
      _e -> :error
    end
  end

  def handle_incoming(%{"type" => "Like", "object" => object_id, "actor" => actor, "id" => id} = data) do
    with %User{} = actor <- User.get_or_fetch_by_ap_id(actor),
         {:ok, object} <- get_obj_helper(object_id) || ActivityPub.fetch_object_from_id(object_id),
         {:ok, activity, object} <- ActivityPub.like(actor, object, id, false) do
      {:ok, activity}
    else
      _e -> :error
    end
  end

  def handle_incoming(%{"type" => "Announce", "object" => object_id, "actor" => actor, "id" => id} = data) do
    with %User{} = actor <- User.get_or_fetch_by_ap_id(actor),
         {:ok, object} <- get_obj_helper(object_id) || ActivityPub.fetch_object_from_id(object_id),
         {:ok, activity, object} <- ActivityPub.announce(actor, object, id, false) do
      {:ok, activity}
    else
      _e -> :error
    end
  end

  # TODO
  # Accept
  # Undo

  def handle_incoming(_), do: :error

  def get_obj_helper(id) do
    if object = Object.get_by_ap_id(id), do: {:ok, object}, else: nil
  end

  def prepare_object(object) do
    object
    |> set_sensitive
    |> add_hashtags
    |> add_mention_tags
    |> add_attributed_to
    |> prepare_attachments
    |> set_conversation
  end

  @doc
  """
  internal -> Mastodon
  """
  def prepare_outgoing(%{"type" => "Create", "object" => %{"type" => "Note"} = object} = data) do
    object = object
    |> prepare_object
    data = data
    |> Map.put("object", object)
    |> Map.put("@context", "https://www.w3.org/ns/activitystreams")

    {:ok, data}
  end

  def prepare_outgoing(%{"type" => type} = data) do
    data = data
    |> Map.put("@context", "https://www.w3.org/ns/activitystreams")

    {:ok, data}
  end

  def add_hashtags(object) do
    tags = (object["tag"] || [])
    |> Enum.map fn (tag) -> %{"href" => Pleroma.Web.Endpoint.url() <> "/tags/#{tag}", "name" => "##{tag}", "type" => "Hashtag"} end

    object
    |> Map.put("tag", tags)
  end

  def add_mention_tags(object) do
    recipients = object["to"] ++ (object["cc"] || [])
    mentions = recipients
    |> Enum.map(fn (ap_id) -> User.get_cached_by_ap_id(ap_id) end)
    |> Enum.filter(&(&1))
    |> Enum.map(fn(user) -> %{"type" => "Mention", "href" => user.ap_id, "name" => "@#{user.nickname}"} end)

    tags = object["tag"] || []

    object
    |> Map.put("tag", tags ++ mentions)
  end

  def set_conversation(object) do
    Map.put(object, "conversation", object["context"])
  end

  def set_sensitive(object) do
    tags = object["tag"] || []
    Map.put(object, "sensitive", "nsfw" in tags)
  end

  def add_attributed_to(object) do
    attributedTo = object["attributedTo"] || object["actor"]

    object
    |> Map.put("attributedTo", attributedTo)
  end

  def prepare_attachments(object) do
    attachments = (object["attachment"] || [])
    |> Enum.map(fn (data) ->
      [%{"mediaType" => media_type, "href" => href} | _] = data["url"]
      %{"url" => href, "mediaType" => media_type, "name" => data["name"], "type" => "Document"}
    end)

    object
    |> Map.put("attachment", attachments)
  end

  defp user_upgrade_task(user) do
    old_follower_address = User.ap_followers(user)
    q  = from u in User,
    where: ^old_follower_address in u.following,
    update: [set: [following: fragment("array_replace(?,?,?)", u.following, ^old_follower_address, ^user.follower_address)]]
    Repo.update_all(q, [])

    maybe_retire_websub(user.ap_id)

    # Only do this for recent activties, don't go through the whole db.
    since = (Repo.aggregate(Activity, :max, :id) || 0) - 100_000
    q  = from a in Activity,
    where: ^old_follower_address in a.recipients,
    where: a.id > ^since,
    update: [set: [recipients: fragment("array_replace(?,?,?)", a.recipients, ^old_follower_address, ^user.follower_address)]]
    Repo.update_all(q, [])
  end

  def upgrade_user_from_ap_id(ap_id, async \\ true) do
    with %User{local: false} = user <- User.get_by_ap_id(ap_id),
         {:ok, data} <- ActivityPub.fetch_and_prepare_user_from_ap_id(ap_id) do
      data = data
      |> Map.put(:info, Map.merge(user.info, data[:info]))

      {:ok, user} = User.upgrade_changeset(user, data)
      |> Repo.update()

      # This could potentially take a long time, do it in the background
      if async do
        Task.start(fn ->
          user_upgrade_task(user)
        end)
      else
        user_upgrade_task(user)
      end

      {:ok, user}
    else
      e -> e
    end
  end

  def maybe_retire_websub(ap_id) do
    # some sanity checks
    if is_binary(ap_id) && (String.length(ap_id) > 8) do
      q = from ws in Pleroma.Web.Websub.WebsubClientSubscription,
        where: fragment("? like ?", ws.topic, ^"#{ap_id}%")
      Repo.delete_all(q)
    end
  end
end
