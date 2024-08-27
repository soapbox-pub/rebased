# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Builder do
  @moduledoc """
  This module builds the objects. Meant to be used for creating local objects.

  This module encodes our addressing policies and general shape of our objects.
  """

  alias Pleroma.Activity
  alias Pleroma.Emoji
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.CommonAPI.ActivityDraft
  alias Pleroma.Web.Endpoint

  require Pleroma.Constants

  def accept_or_reject(actor, activity, type) do
    data = %{
      "id" => Utils.generate_activity_id(),
      "actor" => actor.ap_id,
      "type" => type,
      "object" => activity.data["id"],
      "to" => [activity.actor]
    }

    {:ok, data, []}
  end

  @spec reject(User.t(), Activity.t()) :: {:ok, map(), keyword()}
  def reject(actor, rejected_activity) do
    accept_or_reject(actor, rejected_activity, "Reject")
  end

  @spec accept(User.t(), Activity.t()) :: {:ok, map(), keyword()}
  def accept(actor, accepted_activity) do
    accept_or_reject(actor, accepted_activity, "Accept")
  end

  @spec follow(User.t(), User.t()) :: {:ok, map(), keyword()}
  def follow(follower, followed) do
    data = %{
      "id" => Utils.generate_activity_id(),
      "actor" => follower.ap_id,
      "type" => "Follow",
      "object" => followed.ap_id,
      "to" => [followed.ap_id]
    }

    {:ok, data, []}
  end

  defp unicode_emoji_react(_object, data, emoji) do
    data
    |> Map.put("content", emoji)
    |> Map.put("type", "EmojiReact")
  end

  defp add_emoji_content(data, emoji, url) do
    tag = [
      %{
        "id" => url,
        "type" => "Emoji",
        "name" => Emoji.maybe_quote(emoji),
        "icon" => %{
          "type" => "Image",
          "url" => url
        }
      }
    ]

    data
    |> Map.put("content", Emoji.maybe_quote(emoji))
    |> Map.put("type", "EmojiReact")
    |> Map.put("tag", tag)
  end

  defp remote_custom_emoji_react(
         %{data: %{"reactions" => existing_reactions}},
         data,
         emoji
       ) do
    [emoji_code, instance] = String.split(Emoji.maybe_strip_name(emoji), "@")

    matching_reaction =
      Enum.find(
        existing_reactions,
        fn [name, _, url] ->
          if url != nil do
            url = URI.parse(url)
            url.host == instance && name == emoji_code
          end
        end
      )

    if matching_reaction do
      [name, _, url] = matching_reaction
      add_emoji_content(data, name, url)
    else
      {:error, "Could not react"}
    end
  end

  defp remote_custom_emoji_react(_object, _data, _emoji) do
    {:error, "Could not react"}
  end

  defp local_custom_emoji_react(data, emoji) do
    with %{file: path} = emojo <- Emoji.get(emoji) do
      url = "#{Endpoint.url()}#{path}"
      add_emoji_content(data, emojo.code, url)
    else
      _ -> {:error, "Emoji does not exist"}
    end
  end

  defp custom_emoji_react(object, data, emoji) do
    if String.contains?(emoji, "@") do
      remote_custom_emoji_react(object, data, emoji)
    else
      local_custom_emoji_react(data, emoji)
    end
  end

  @spec emoji_react(User.t(), Object.t(), String.t()) :: {:ok, map(), keyword()}
  def emoji_react(actor, object, emoji) do
    with {:ok, data, meta} <- object_action(actor, object) do
      data =
        if Emoji.unicode?(emoji) do
          unicode_emoji_react(object, data, emoji)
        else
          custom_emoji_react(object, data, emoji)
        end

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
    object = Object.normalize(object_id, fetch: false)

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
    context =
      if is_map(object) do
        object["context"]
      else
        nil
      end

    {:ok,
     %{
       "id" => Utils.generate_activity_id(),
       "actor" => actor.ap_id,
       "to" => recipients,
       "object" => object,
       "type" => "Create",
       "published" => DateTime.utc_now() |> DateTime.to_iso8601()
     }
     |> Pleroma.Maps.put_if_present("context", context), []}
  end

  @spec note(ActivityDraft.t()) :: {:ok, map(), keyword()}
  def note(%ActivityDraft{} = draft) do
    data =
      %{
        "type" => "Note",
        "to" => draft.to,
        "cc" => draft.cc,
        "content" => draft.content_html,
        "summary" => draft.summary,
        "sensitive" => draft.sensitive,
        "context" => draft.context,
        "attachment" => draft.attachments,
        "actor" => draft.user.ap_id,
        "tag" => Keyword.values(draft.tags) |> Enum.uniq()
      }
      |> add_in_reply_to(draft.in_reply_to)
      |> add_quote(draft.quote_post)
      |> Map.merge(draft.extra)

    {:ok, data, []}
  end

  defp add_in_reply_to(object, nil), do: object

  defp add_in_reply_to(object, in_reply_to) do
    with %Object{} = in_reply_to_object <- Object.normalize(in_reply_to, fetch: false) do
      Map.put(object, "inReplyTo", in_reply_to_object.data["id"])
    else
      _ -> object
    end
  end

  defp add_quote(object, nil), do: object

  defp add_quote(object, quote_post) do
    with %Object{} = quote_object <- Object.normalize(quote_post, fetch: false) do
      Map.put(object, "quoteUrl", quote_object.data["id"])
    else
      _ -> object
    end
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

  def answer(user, object, name) do
    {:ok,
     %{
       "type" => "Answer",
       "actor" => user.ap_id,
       "attributedTo" => user.ap_id,
       "cc" => [object.data["actor"]],
       "to" => [],
       "name" => name,
       "inReplyTo" => object.data["id"],
       "context" => object.data["context"],
       "published" => DateTime.utc_now() |> DateTime.to_iso8601(),
       "id" => Utils.generate_object_id()
     }, []}
  end

  @spec tombstone(String.t(), String.t()) :: {:ok, map(), keyword()}
  def tombstone(actor, id) do
    {:ok,
     %{
       "id" => id,
       "actor" => actor,
       "type" => "Tombstone"
     }, []}
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

  @spec update(User.t(), Object.t()) :: {:ok, map(), keyword()}
  def update(actor, object) do
    {to, cc} =
      if object["type"] in Pleroma.Constants.actor_types() do
        # User updates, always public
        {[Pleroma.Constants.as_public(), actor.follower_address], []}
      else
        # Status updates, follow the recipients in the object
        {object["to"] || [], object["cc"] || []}
      end

    {:ok,
     %{
       "id" => Utils.generate_activity_id(),
       "type" => "Update",
       "actor" => actor.ap_id,
       "object" => object,
       "to" => to,
       "cc" => cc
     }, []}
  end

  @spec block(User.t(), User.t()) :: {:ok, map(), keyword()}
  def block(blocker, blocked) do
    {:ok,
     %{
       "id" => Utils.generate_activity_id(),
       "type" => "Block",
       "actor" => blocker.ap_id,
       "object" => blocked.ap_id,
       "to" => [blocked.ap_id]
     }, []}
  end

  @spec announce(User.t(), Object.t(), keyword()) :: {:ok, map(), keyword()}
  def announce(actor, object, options \\ []) do
    public? = Keyword.get(options, :public, false)

    to =
      cond do
        actor.ap_id == Relay.ap_id() ->
          [actor.follower_address]

        public? and Visibility.local_public?(object) ->
          [actor.follower_address, object.data["actor"], Utils.as_local_public()]

        public? ->
          [actor.follower_address, object.data["actor"], Pleroma.Constants.as_public()]

        true ->
          [actor.follower_address, object.data["actor"]]
      end

    {:ok,
     %{
       "id" => Utils.generate_activity_id(),
       "actor" => actor.ap_id,
       "object" => object.data["id"],
       "to" => to,
       "context" => object.data["context"],
       "type" => "Announce",
       "published" => Utils.make_date()
     }, []}
  end

  @spec object_action(User.t(), Object.t()) :: {:ok, map(), keyword()}
  defp object_action(actor, object) do
    object_actor = User.get_cached_by_ap_id(object.data["actor"])

    # Address the actor of the object, and our actor's follower collection if the post is public.
    to =
      if Visibility.public?(object) do
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

  @spec pin(User.t(), Object.t()) :: {:ok, map(), keyword()}
  def pin(%User{} = user, object) do
    {:ok,
     %{
       "id" => Utils.generate_activity_id(),
       "target" => pinned_url(user.nickname),
       "object" => object.data["id"],
       "actor" => user.ap_id,
       "type" => "Add",
       "to" => [Pleroma.Constants.as_public()],
       "cc" => [user.follower_address]
     }, []}
  end

  @spec unpin(User.t(), Object.t()) :: {:ok, map, keyword()}
  def unpin(%User{} = user, object) do
    {:ok,
     %{
       "id" => Utils.generate_activity_id(),
       "target" => pinned_url(user.nickname),
       "object" => object.data["id"],
       "actor" => user.ap_id,
       "type" => "Remove",
       "to" => [Pleroma.Constants.as_public()],
       "cc" => [user.follower_address]
     }, []}
  end

  defp pinned_url(nickname) when is_binary(nickname) do
    Pleroma.Web.Router.Helpers.activity_pub_url(Pleroma.Web.Endpoint, :pinned, nickname)
  end

  def bite(%User{} = biting, %User{} = bitten) do
    {:ok,
     %{
       "id" => Utils.generate_activity_id(),
       "target" => bitten.ap_id,
       "actor" => biting.ap_id,
       "type" => "Bite",
       "to" => [bitten.ap_id]
     }, []}
  end
end
