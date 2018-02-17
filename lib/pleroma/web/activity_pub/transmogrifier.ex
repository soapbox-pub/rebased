defmodule Pleroma.Web.ActivityPub.Transmogrifier do
  @moduledoc """
  A module to handle coding from internal to wire ActivityPub and back.
  """
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub

  @doc """
  Modifies an incoming AP object (mastodon format) to our internal format.
  """
  def fix_object(object) do
    object
    |> Map.put("actor", object["attributedTo"])
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

  @doc
  """
  internal -> Mastodon
  """
  def prepare_outgoing(%{"type" => "Create", "object" => %{"type" => "Note"} = object} = data) do
    object = object
    |> add_mention_tags
    |> add_attributed_to

    data = data
    |> Map.put("object", object)
    |> Map.put("@context", "https://www.w3.org/ns/activitystreams")

    {:ok, data}
  end

  def add_mention_tags(object) do
    mentions = object["to"]
    |> Enum.map(fn (ap_id) -> User.get_cached_by_ap_id(ap_id) end)
    |> Enum.filter(&(&1))
    |> Enum.map(fn(user) -> %{"type" => "mention", "href" => user.ap_id, "name" => "@#{user.nickname}"} end)

    tags = object["tags"] || []

    object
    |> Map.put("tags", tags ++ mentions)
  end

  def add_attributed_to(object) do
    attributedTo = object["attributedTo"] || object["actor"]

    object
    |> Map.put("attributedTo", attributedTo)
  end
end
