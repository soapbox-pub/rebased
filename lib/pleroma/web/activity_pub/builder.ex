defmodule Pleroma.Web.ActivityPub.Builder do
  @moduledoc """
  This module builds the objects. Meant to be used for creating local objects.

  This module encodes our addressing policies and general shape of our objects.
  """

  alias Pleroma.Emoji
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.ActivityPub.Visibility

  @spec emoji_react(User.t(), Object.t(), String.t()) :: {:ok, map(), keyword()}
  def emoji_react(actor, object, emoji) do
    with {:ok, data, meta} <- object_action(actor, object) do
      data =
        data
        |> Map.put("content", emoji)
        |> Map.put("type", "EmojiReact")

      {:ok, data, meta}
    end
  end

  @spec undo(User.t(), Activity.t()) :: {:ok, map(), keyword()}
  def undo(actor, object) do
    {:ok,
     %{
       "id" => Utils.generate_activity_id(),
       "actor" => actor.ap_id,
       "type" => "Undo",
       "object" => object.data["id"],
       "to" => object.data["to"] || [],
       "cc" => object.data["cc"] || []
     }, []}
  end

  @spec delete(User.t(), String.t()) :: {:ok, map(), keyword()}
  def delete(actor, object_id) do
    object = Object.normalize(object_id, false)

    user = !object && User.get_cached_by_ap_id(object_id)

    to =
      case {object, user} do
        {%Object{}, _} ->
          # We are deleting an object, address everyone who was originally mentioned
          (object.data["to"] || []) ++ (object.data["cc"] || [])

        {_, %User{follower_address: follower_address}} ->
          # We are deleting a user, address the followers of that user
          [follower_address]
      end

    {:ok,
     %{
       "id" => Utils.generate_activity_id(),
       "actor" => actor.ap_id,
       "object" => object_id,
       "to" => to,
       "type" => "Delete"
     }, []}
  end

  def create(actor, object, recipients) do
    {:ok,
     %{
       "id" => Utils.generate_activity_id(),
       "actor" => actor.ap_id,
       "to" => recipients,
       "object" => object,
       "type" => "Create",
       "published" => DateTime.utc_now() |> DateTime.to_iso8601()
     }, []}
  end

  def chat_message(actor, recipient, content, opts \\ []) do
    basic = %{
      "id" => Utils.generate_object_id(),
      "actor" => actor.ap_id,
      "type" => "ChatMessage",
      "to" => [recipient],
      "content" => content,
      "published" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "emoji" => Emoji.Formatter.get_emoji_map(content)
    }

    case opts[:attachment] do
      %Object{data: attachment_data} ->
        {
          :ok,
          Map.put(basic, "attachment", attachment_data),
          []
        }

      _ ->
        {:ok, basic, []}
    end
  end

  @spec like(User.t(), Object.t()) :: {:ok, map(), keyword()}
  def like(actor, object) do
    with {:ok, data, meta} <- object_action(actor, object) do
      data =
        data
        |> Map.put("type", "Like")

      {:ok, data, meta}
    end
  end

  @spec object_action(User.t(), Object.t()) :: {:ok, map(), keyword()}
  defp object_action(actor, object) do
    object_actor = User.get_cached_by_ap_id(object.data["actor"])

    # Address the actor of the object, and our actor's follower collection if the post is public.
    to =
      if Visibility.is_public?(object) do
        [actor.follower_address, object.data["actor"]]
      else
        [object.data["actor"]]
      end

    # CC everyone who's been addressed in the object, except ourself and the object actor's
    # follower collection
    cc =
      (object.data["to"] ++ (object.data["cc"] || []))
      |> List.delete(actor.ap_id)
      |> List.delete(object_actor.follower_address)

    {:ok,
     %{
       "id" => Utils.generate_activity_id(),
       "actor" => actor.ap_id,
       "object" => object.data["id"],
       "to" => to,
       "cc" => cc,
       "context" => object.data["context"]
     }, []}
  end
end
