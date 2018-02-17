defmodule Pleroma.Web.ActivityPub.Transmogrifier do
  @moduledoc """
  A module to handle coding from internal to wire ActivityPub and back.
  """
  alias Pleroma.User
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.ActivityPub

  @doc """
  Modifies an incoming AP object (mastodon format) to our internal format.
  """
  def fix_object(object) do
    object
    |> Map.put("actor", object["attributedTo"])
    |> fix_attachments
  end

  def fix_attachments(object) do
    attachments = object["attachment"] || []
    |> Enum.map(fn (data) ->
      url = [%{"type" => "Link", "mediaType" => data["mediaType"], "url" => data["url"]}]
      Map.put(data, "url", url)
    end)

    object
    |> Map.put("attachment", attachments)
  end

  # TODO: validate those with a Ecto scheme
  # - tags
  # - emoji
  def handle_incoming(%{"type" => "Create", "object" => %{"type" => "Note"} = object} = data) do
    with %User{} = user <- User.get_or_fetch_by_ap_id(data["actor"]) do
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
         %Object{} = object <- Object.get_by_ap_id(object_id),
         {:ok, activity, object} <- ActivityPub.like(actor, object, id, false) do
      {:ok, activity}
    else
      _e -> :error
    end
  end

  # TODO
  # Accept
  # Undo

  def handle_incoming(_), do: :error

  @doc
  """
  internal -> Mastodon
  """
  def prepare_outgoing(%{"type" => "Create", "object" => %{"type" => "Note"} = object} = data) do
    object = object
    |> add_mention_tags
    |> add_attributed_to
    |> prepare_attachments

    data = data
    |> Map.put("object", object)
    |> Map.put("@context", "https://www.w3.org/ns/activitystreams")

    {:ok, data}
  end

  def prepare_outgoing(%{"type" => type} = data) when type in ["Follow", "Accept", "Like", "Announce"] do
    data = data
    |> Map.put("@context", "https://www.w3.org/ns/activitystreams")

    {:ok, data}
  end

  def add_mention_tags(object) do
    mentions = object["to"]
    |> Enum.map(fn (ap_id) -> User.get_cached_by_ap_id(ap_id) end)
    |> Enum.filter(&(&1))
    |> Enum.map(fn(user) -> %{"type" => "Mention", "href" => user.ap_id, "name" => "@#{user.nickname}"} end)

    tags = object["tag"] || []

    object
    |> Map.put("tag", tags ++ mentions)
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
end
