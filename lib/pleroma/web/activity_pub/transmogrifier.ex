# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier do
  @moduledoc """
  A module to handle coding from internal to wire ActivityPub and back.
  """
  alias Pleroma.Activity
  alias Pleroma.FollowingRelationship
  alias Pleroma.Object
  alias Pleroma.Object.Containment
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.Federator
  alias Pleroma.Workers.TransmogrifierWorker

  import Ecto.Query

  require Logger
  require Pleroma.Constants

  @doc """
  Modifies an incoming AP object (mastodon format) to our internal format.
  """
  def fix_object(object, options \\ []) do
    object
    |> strip_internal_fields
    |> fix_actor
    |> fix_url
    |> fix_attachments
    |> fix_context
    |> fix_in_reply_to(options)
    |> fix_emoji
    |> fix_tag
    |> fix_content_map
    |> fix_addressing
    |> fix_summary
    |> fix_type(options)
  end

  def fix_summary(%{"summary" => nil} = object) do
    Map.put(object, "summary", "")
  end

  def fix_summary(%{"summary" => _} = object) do
    # summary is present, nothing to do
    object
  end

  def fix_summary(object), do: Map.put(object, "summary", "")

  def fix_addressing_list(map, field) do
    cond do
      is_binary(map[field]) ->
        Map.put(map, field, [map[field]])

      is_nil(map[field]) ->
        Map.put(map, field, [])

      true ->
        map
    end
  end

  def fix_explicit_addressing(
        %{"to" => to, "cc" => cc} = object,
        explicit_mentions,
        follower_collection
      ) do
    explicit_to = Enum.filter(to, fn x -> x in explicit_mentions end)

    explicit_cc = Enum.filter(to, fn x -> x not in explicit_mentions end)

    final_cc =
      (cc ++ explicit_cc)
      |> Enum.reject(fn x -> String.ends_with?(x, "/followers") and x != follower_collection end)
      |> Enum.uniq()

    object
    |> Map.put("to", explicit_to)
    |> Map.put("cc", final_cc)
  end

  def fix_explicit_addressing(object, _explicit_mentions, _followers_collection), do: object

  # if directMessage flag is set to true, leave the addressing alone
  def fix_explicit_addressing(%{"directMessage" => true} = object), do: object

  def fix_explicit_addressing(object) do
    explicit_mentions = Utils.determine_explicit_mentions(object)

    %User{follower_address: follower_collection} =
      object
      |> Containment.get_actor()
      |> User.get_cached_by_ap_id()

    explicit_mentions =
      explicit_mentions ++
        [
          Pleroma.Constants.as_public(),
          follower_collection
        ]

    fix_explicit_addressing(object, explicit_mentions, follower_collection)
  end

  # if as:Public is addressed, then make sure the followers collection is also addressed
  # so that the activities will be delivered to local users.
  def fix_implicit_addressing(%{"to" => to, "cc" => cc} = object, followers_collection) do
    recipients = to ++ cc

    if followers_collection not in recipients do
      cond do
        Pleroma.Constants.as_public() in cc ->
          to = to ++ [followers_collection]
          Map.put(object, "to", to)

        Pleroma.Constants.as_public() in to ->
          cc = cc ++ [followers_collection]
          Map.put(object, "cc", cc)

        true ->
          object
      end
    else
      object
    end
  end

  def fix_implicit_addressing(object, _), do: object

  def fix_addressing(object) do
    {:ok, %User{} = user} = User.get_or_fetch_by_ap_id(object["actor"])
    followers_collection = User.ap_followers(user)

    object
    |> fix_addressing_list("to")
    |> fix_addressing_list("cc")
    |> fix_addressing_list("bto")
    |> fix_addressing_list("bcc")
    |> fix_explicit_addressing()
    |> fix_implicit_addressing(followers_collection)
  end

  def fix_actor(%{"attributedTo" => actor} = object) do
    Map.put(object, "actor", Containment.get_actor(%{"actor" => actor}))
  end

  def fix_in_reply_to(object, options \\ [])

  def fix_in_reply_to(%{"inReplyTo" => in_reply_to} = object, options)
      when not is_nil(in_reply_to) do
    in_reply_to_id = prepare_in_reply_to(in_reply_to)
    object = Map.put(object, "inReplyToAtomUri", in_reply_to_id)
    depth = (options[:depth] || 0) + 1

    if Federator.allowed_thread_distance?(depth) do
      with {:ok, replied_object} <- get_obj_helper(in_reply_to_id, options),
           %Activity{} <- Activity.get_create_by_object_ap_id(replied_object.data["id"]) do
        object
        |> Map.put("inReplyTo", replied_object.data["id"])
        |> Map.put("inReplyToAtomUri", object["inReplyToAtomUri"] || in_reply_to_id)
        |> Map.put("conversation", replied_object.data["context"] || object["conversation"])
        |> Map.put("context", replied_object.data["context"] || object["conversation"])
      else
        e ->
          Logger.error("Couldn't fetch #{inspect(in_reply_to_id)}, error: #{inspect(e)}")
          object
      end
    else
      object
    end
  end

  def fix_in_reply_to(object, _options), do: object

  defp prepare_in_reply_to(in_reply_to) do
    cond do
      is_bitstring(in_reply_to) ->
        in_reply_to

      is_map(in_reply_to) && is_bitstring(in_reply_to["id"]) ->
        in_reply_to["id"]

      is_list(in_reply_to) && is_bitstring(Enum.at(in_reply_to, 0)) ->
        Enum.at(in_reply_to, 0)

      true ->
        ""
    end
  end

  def fix_context(object) do
    context = object["context"] || object["conversation"] || Utils.generate_context_id()

    object
    |> Map.put("context", context)
    |> Map.put("conversation", context)
  end

  defp add_if_present(map, _key, nil), do: map

  defp add_if_present(map, key, value) do
    Map.put(map, key, value)
  end

  def fix_attachments(%{"attachment" => attachment} = object) when is_list(attachment) do
    attachments =
      Enum.map(attachment, fn data ->
        url =
          cond do
            is_list(data["url"]) -> List.first(data["url"])
            is_map(data["url"]) -> data["url"]
            true -> nil
          end

        media_type =
          cond do
            is_map(url) && is_binary(url["mediaType"]) -> url["mediaType"]
            is_binary(data["mediaType"]) -> data["mediaType"]
            is_binary(data["mimeType"]) -> data["mimeType"]
            true -> nil
          end

        href =
          cond do
            is_map(url) && is_binary(url["href"]) -> url["href"]
            is_binary(data["url"]) -> data["url"]
            is_binary(data["href"]) -> data["href"]
          end

        attachment_url =
          %{"href" => href}
          |> add_if_present("mediaType", media_type)
          |> add_if_present("type", Map.get(url || %{}, "type"))

        %{"url" => [attachment_url]}
        |> add_if_present("mediaType", media_type)
        |> add_if_present("type", data["type"])
        |> add_if_present("name", data["name"])
      end)

    Map.put(object, "attachment", attachments)
  end

  def fix_attachments(%{"attachment" => attachment} = object) when is_map(attachment) do
    object
    |> Map.put("attachment", [attachment])
    |> fix_attachments()
  end

  def fix_attachments(object), do: object

  def fix_url(%{"url" => url} = object) when is_map(url) do
    Map.put(object, "url", url["href"])
  end

  def fix_url(%{"type" => "Video", "url" => url} = object) when is_list(url) do
    first_element = Enum.at(url, 0)

    link_element = Enum.find(url, fn x -> is_map(x) and x["mimeType"] == "text/html" end)

    object
    |> Map.put("attachment", [first_element])
    |> Map.put("url", link_element["href"])
  end

  def fix_url(%{"type" => object_type, "url" => url} = object)
      when object_type != "Video" and is_list(url) do
    first_element = Enum.at(url, 0)

    url_string =
      cond do
        is_bitstring(first_element) -> first_element
        is_map(first_element) -> first_element["href"] || ""
        true -> ""
      end

    Map.put(object, "url", url_string)
  end

  def fix_url(object), do: object

  def fix_emoji(%{"tag" => tags} = object) when is_list(tags) do
    emoji =
      tags
      |> Enum.filter(fn data -> data["type"] == "Emoji" and data["icon"] end)
      |> Enum.reduce(%{}, fn data, mapping ->
        name = String.trim(data["name"], ":")

        Map.put(mapping, name, data["icon"]["url"])
      end)

    # we merge mastodon and pleroma emoji into a single mapping, to allow for both wire formats
    emoji = Map.merge(object["emoji"] || %{}, emoji)

    Map.put(object, "emoji", emoji)
  end

  def fix_emoji(%{"tag" => %{"type" => "Emoji"} = tag} = object) do
    name = String.trim(tag["name"], ":")
    emoji = %{name => tag["icon"]["url"]}

    Map.put(object, "emoji", emoji)
  end

  def fix_emoji(object), do: object

  def fix_tag(%{"tag" => tag} = object) when is_list(tag) do
    tags =
      tag
      |> Enum.filter(fn data -> data["type"] == "Hashtag" and data["name"] end)
      |> Enum.map(fn data -> String.slice(data["name"], 1..-1) end)

    Map.put(object, "tag", tag ++ tags)
  end

  def fix_tag(%{"tag" => %{"type" => "Hashtag", "name" => hashtag} = tag} = object) do
    combined = [tag, String.slice(hashtag, 1..-1)]

    Map.put(object, "tag", combined)
  end

  def fix_tag(%{"tag" => %{} = tag} = object), do: Map.put(object, "tag", [tag])

  def fix_tag(object), do: object

  # content map usually only has one language so this will do for now.
  def fix_content_map(%{"contentMap" => content_map} = object) do
    content_groups = Map.to_list(content_map)
    {_, content} = Enum.at(content_groups, 0)

    Map.put(object, "content", content)
  end

  def fix_content_map(object), do: object

  def fix_type(object, options \\ [])

  def fix_type(%{"inReplyTo" => reply_id, "name" => _} = object, options)
      when is_binary(reply_id) do
    with true <- Federator.allowed_thread_distance?(options[:depth]),
         {:ok, %{data: %{"type" => "Question"} = _} = _} <- get_obj_helper(reply_id, options) do
      Map.put(object, "type", "Answer")
    else
      _ -> object
    end
  end

  def fix_type(object, _), do: object

  defp mastodon_follow_hack(%{"id" => id, "actor" => follower_id}, followed) do
    with true <- id =~ "follows",
         %User{local: true} = follower <- User.get_cached_by_ap_id(follower_id),
         %Activity{} = activity <- Utils.fetch_latest_follow(follower, followed) do
      {:ok, activity}
    else
      _ -> {:error, nil}
    end
  end

  defp mastodon_follow_hack(_, _), do: {:error, nil}

  defp get_follow_activity(follow_object, followed) do
    with object_id when not is_nil(object_id) <- Utils.get_ap_id(follow_object),
         {_, %Activity{} = activity} <- {:activity, Activity.get_by_ap_id(object_id)} do
      {:ok, activity}
    else
      # Can't find the activity. This might a Mastodon 2.3 "Accept"
      {:activity, nil} ->
        mastodon_follow_hack(follow_object, followed)

      _ ->
        {:error, nil}
    end
  end

  # Reduce the object list to find the reported user.
  defp get_reported(objects) do
    Enum.reduce_while(objects, nil, fn ap_id, _ ->
      with %User{} = user <- User.get_cached_by_ap_id(ap_id) do
        {:halt, user}
      else
        _ -> {:cont, nil}
      end
    end)
  end

  def handle_incoming(data, options \\ [])

  # Flag objects are placed ahead of the ID check because Mastodon 2.8 and earlier send them
  # with nil ID.
  def handle_incoming(%{"type" => "Flag", "object" => objects, "actor" => actor} = data, _options) do
    with context <- data["context"] || Utils.generate_context_id(),
         content <- data["content"] || "",
         %User{} = actor <- User.get_cached_by_ap_id(actor),
         # Reduce the object list to find the reported user.
         %User{} = account <- get_reported(objects),
         # Remove the reported user from the object list.
         statuses <- Enum.filter(objects, fn ap_id -> ap_id != account.ap_id end) do
      %{
        actor: actor,
        context: context,
        account: account,
        statuses: statuses,
        content: content,
        additional: %{"cc" => [account.ap_id]}
      }
      |> ActivityPub.flag()
    end
  end

  # disallow objects with bogus IDs
  def handle_incoming(%{"id" => nil}, _options), do: :error
  def handle_incoming(%{"id" => ""}, _options), do: :error
  # length of https:// = 8, should validate better, but good enough for now.
  def handle_incoming(%{"id" => id}, _options) when is_binary(id) and byte_size(id) < 8,
    do: :error

  # TODO: validate those with a Ecto scheme
  # - tags
  # - emoji
  def handle_incoming(
        %{"type" => "Create", "object" => %{"type" => objtype} = object} = data,
        options
      )
      when objtype in ["Article", "Event", "Note", "Video", "Page", "Question", "Answer"] do
    actor = Containment.get_actor(data)

    data =
      Map.put(data, "actor", actor)
      |> fix_addressing

    with nil <- Activity.get_create_by_object_ap_id(object["id"]),
         {:ok, %User{} = user} <- User.get_or_fetch_by_ap_id(data["actor"]) do
      object = fix_object(object, options)

      params = %{
        to: data["to"],
        object: object,
        actor: user,
        context: object["conversation"],
        local: false,
        published: data["published"],
        additional:
          Map.take(data, [
            "cc",
            "directMessage",
            "id"
          ])
      }

      with {:ok, created_activity} <- ActivityPub.create(params) do
        reply_depth = (options[:depth] || 0) + 1

        if Federator.allowed_thread_distance?(reply_depth) do
          for reply_id <- replies(object) do
            Pleroma.Workers.RemoteFetcherWorker.enqueue("fetch_remote", %{
              "id" => reply_id,
              "depth" => reply_depth
            })
          end
        end

        {:ok, created_activity}
      end
    else
      %Activity{} = activity -> {:ok, activity}
      _e -> :error
    end
  end

  def handle_incoming(
        %{"type" => "Listen", "object" => %{"type" => "Audio"} = object} = data,
        options
      ) do
    actor = Containment.get_actor(data)

    data =
      Map.put(data, "actor", actor)
      |> fix_addressing

    with {:ok, %User{} = user} <- User.get_or_fetch_by_ap_id(data["actor"]) do
      reply_depth = (options[:depth] || 0) + 1
      options = Keyword.put(options, :depth, reply_depth)
      object = fix_object(object, options)

      params = %{
        to: data["to"],
        object: object,
        actor: user,
        context: nil,
        local: false,
        published: data["published"],
        additional: Map.take(data, ["cc", "id"])
      }

      ActivityPub.listen(params)
    else
      _e -> :error
    end
  end

  def handle_incoming(
        %{"type" => "Follow", "object" => followed, "actor" => follower, "id" => id} = data,
        _options
      ) do
    with %User{local: true} = followed <-
           User.get_cached_by_ap_id(Containment.get_actor(%{"actor" => followed})),
         {:ok, %User{} = follower} <-
           User.get_or_fetch_by_ap_id(Containment.get_actor(%{"actor" => follower})),
         {:ok, activity} <- ActivityPub.follow(follower, followed, id, false) do
      with deny_follow_blocked <- Pleroma.Config.get([:user, :deny_follow_blocked]),
           {_, false} <- {:user_blocked, User.blocks?(followed, follower) && deny_follow_blocked},
           {_, false} <- {:user_locked, User.locked?(followed)},
           {_, {:ok, follower}} <- {:follow, User.follow(follower, followed)},
           {_, {:ok, _}} <-
             {:follow_state_update, Utils.update_follow_state_for_all(activity, "accept")},
           {:ok, _relationship} <- FollowingRelationship.update(follower, followed, "accept") do
        ActivityPub.accept(%{
          to: [follower.ap_id],
          actor: followed,
          object: data,
          local: true
        })
      else
        {:user_blocked, true} ->
          {:ok, _} = Utils.update_follow_state_for_all(activity, "reject")
          {:ok, _relationship} = FollowingRelationship.update(follower, followed, "reject")

          ActivityPub.reject(%{
            to: [follower.ap_id],
            actor: followed,
            object: data,
            local: true
          })

        {:follow, {:error, _}} ->
          {:ok, _} = Utils.update_follow_state_for_all(activity, "reject")
          {:ok, _relationship} = FollowingRelationship.update(follower, followed, "reject")

          ActivityPub.reject(%{
            to: [follower.ap_id],
            actor: followed,
            object: data,
            local: true
          })

        {:user_locked, true} ->
          {:ok, _relationship} = FollowingRelationship.update(follower, followed, "pending")
          :noop
      end

      {:ok, activity}
    else
      _e ->
        :error
    end
  end

  def handle_incoming(
        %{"type" => "Accept", "object" => follow_object, "actor" => _actor, "id" => id} = data,
        _options
      ) do
    with actor <- Containment.get_actor(data),
         {:ok, %User{} = followed} <- User.get_or_fetch_by_ap_id(actor),
         {:ok, follow_activity} <- get_follow_activity(follow_object, followed),
         {:ok, follow_activity} <- Utils.update_follow_state_for_all(follow_activity, "accept"),
         %User{local: true} = follower <- User.get_cached_by_ap_id(follow_activity.data["actor"]),
         {:ok, _relationship} <- FollowingRelationship.update(follower, followed, "accept") do
      ActivityPub.accept(%{
        to: follow_activity.data["to"],
        type: "Accept",
        actor: followed,
        object: follow_activity.data["id"],
        local: false,
        activity_id: id
      })
    else
      _e -> :error
    end
  end

  def handle_incoming(
        %{"type" => "Reject", "object" => follow_object, "actor" => _actor, "id" => id} = data,
        _options
      ) do
    with actor <- Containment.get_actor(data),
         {:ok, %User{} = followed} <- User.get_or_fetch_by_ap_id(actor),
         {:ok, follow_activity} <- get_follow_activity(follow_object, followed),
         {:ok, follow_activity} <- Utils.update_follow_state_for_all(follow_activity, "reject"),
         %User{local: true} = follower <- User.get_cached_by_ap_id(follow_activity.data["actor"]),
         {:ok, _relationship} <- FollowingRelationship.update(follower, followed, "reject"),
         {:ok, activity} <-
           ActivityPub.reject(%{
             to: follow_activity.data["to"],
             type: "Reject",
             actor: followed,
             object: follow_activity.data["id"],
             local: false,
             activity_id: id
           }) do
      {:ok, activity}
    else
      _e -> :error
    end
  end

  @misskey_reactions %{
    "like" => "👍",
    "love" => "❤️",
    "laugh" => "😆",
    "hmm" => "🤔",
    "surprise" => "😮",
    "congrats" => "🎉",
    "angry" => "💢",
    "confused" => "😥",
    "rip" => "😇",
    "pudding" => "🍮",
    "star" => "⭐"
  }

  @doc "Rewrite misskey likes into EmojiReacts"
  def handle_incoming(
        %{
          "type" => "Like",
          "_misskey_reaction" => reaction
        } = data,
        options
      ) do
    data
    |> Map.put("type", "EmojiReact")
    |> Map.put("content", @misskey_reactions[reaction] || reaction)
    |> handle_incoming(options)
  end

  def handle_incoming(
        %{"type" => "Like", "object" => object_id, "actor" => _actor, "id" => id} = data,
        _options
      ) do
    with actor <- Containment.get_actor(data),
         {:ok, %User{} = actor} <- User.get_or_fetch_by_ap_id(actor),
         {:ok, object} <- get_obj_helper(object_id),
         {:ok, activity, _object} <- ActivityPub.like(actor, object, id, false) do
      {:ok, activity}
    else
      _e -> :error
    end
  end

  def handle_incoming(
        %{
          "type" => "EmojiReact",
          "object" => object_id,
          "actor" => _actor,
          "id" => id,
          "content" => emoji
        } = data,
        _options
      ) do
    with actor <- Containment.get_actor(data),
         {:ok, %User{} = actor} <- User.get_or_fetch_by_ap_id(actor),
         {:ok, object} <- get_obj_helper(object_id),
         {:ok, activity, _object} <-
           ActivityPub.react_with_emoji(actor, object, emoji, activity_id: id, local: false) do
      {:ok, activity}
    else
      _e -> :error
    end
  end

  def handle_incoming(
        %{"type" => "Announce", "object" => object_id, "actor" => _actor, "id" => id} = data,
        _options
      ) do
    with actor <- Containment.get_actor(data),
         {:ok, %User{} = actor} <- User.get_or_fetch_by_ap_id(actor),
         {:ok, object} <- get_embedded_obj_helper(object_id, actor),
         public <- Visibility.is_public?(data),
         {:ok, activity, _object} <- ActivityPub.announce(actor, object, id, false, public) do
      {:ok, activity}
    else
      _e -> :error
    end
  end

  def handle_incoming(
        %{"type" => "Update", "object" => %{"type" => object_type} = object, "actor" => actor_id} =
          data,
        _options
      )
      when object_type in [
             "Person",
             "Application",
             "Service",
             "Organization"
           ] do
    with %User{ap_id: ^actor_id} = actor <- User.get_cached_by_ap_id(object["id"]) do
      {:ok, new_user_data} = ActivityPub.user_data_from_user_object(object)

      actor
      |> User.upgrade_changeset(new_user_data, true)
      |> User.update_and_set_cache()

      ActivityPub.update(%{
        local: false,
        to: data["to"] || [],
        cc: data["cc"] || [],
        object: object,
        actor: actor_id,
        activity_id: data["id"]
      })
    else
      e ->
        Logger.error(e)
        :error
    end
  end

  # TODO: We presently assume that any actor on the same origin domain as the object being
  # deleted has the rights to delete that object.  A better way to validate whether or not
  # the object should be deleted is to refetch the object URI, which should return either
  # an error or a tombstone.  This would allow us to verify that a deletion actually took
  # place.
  def handle_incoming(
        %{"type" => "Delete", "object" => object_id, "actor" => actor, "id" => id} = data,
        _options
      ) do
    object_id = Utils.get_ap_id(object_id)

    with actor <- Containment.get_actor(data),
         {:ok, %User{} = actor} <- User.get_or_fetch_by_ap_id(actor),
         {:ok, object} <- get_obj_helper(object_id),
         :ok <- Containment.contain_origin(actor.ap_id, object.data),
         {:ok, activity} <-
           ActivityPub.delete(object, local: false, activity_id: id, actor: actor.ap_id) do
      {:ok, activity}
    else
      nil ->
        case User.get_cached_by_ap_id(object_id) do
          %User{ap_id: ^actor} = user ->
            User.delete(user)

          nil ->
            :error
        end

      _e ->
        :error
    end
  end

  def handle_incoming(
        %{
          "type" => "Undo",
          "object" => %{"type" => "Announce", "object" => object_id},
          "actor" => _actor,
          "id" => id
        } = data,
        _options
      ) do
    with actor <- Containment.get_actor(data),
         {:ok, %User{} = actor} <- User.get_or_fetch_by_ap_id(actor),
         {:ok, object} <- get_obj_helper(object_id),
         {:ok, activity, _} <- ActivityPub.unannounce(actor, object, id, false) do
      {:ok, activity}
    else
      _e -> :error
    end
  end

  def handle_incoming(
        %{
          "type" => "Undo",
          "object" => %{"type" => "Follow", "object" => followed},
          "actor" => follower,
          "id" => id
        } = _data,
        _options
      ) do
    with %User{local: true} = followed <- User.get_cached_by_ap_id(followed),
         {:ok, %User{} = follower} <- User.get_or_fetch_by_ap_id(follower),
         {:ok, activity} <- ActivityPub.unfollow(follower, followed, id, false) do
      User.unfollow(follower, followed)
      {:ok, activity}
    else
      _e -> :error
    end
  end

  def handle_incoming(
        %{
          "type" => "Undo",
          "object" => %{"type" => "EmojiReact", "id" => reaction_activity_id},
          "actor" => _actor,
          "id" => id
        } = data,
        _options
      ) do
    with actor <- Containment.get_actor(data),
         {:ok, %User{} = actor} <- User.get_or_fetch_by_ap_id(actor),
         {:ok, activity, _} <-
           ActivityPub.unreact_with_emoji(actor, reaction_activity_id,
             activity_id: id,
             local: false
           ) do
      {:ok, activity}
    else
      _e -> :error
    end
  end

  def handle_incoming(
        %{
          "type" => "Undo",
          "object" => %{"type" => "Block", "object" => blocked},
          "actor" => blocker,
          "id" => id
        } = _data,
        _options
      ) do
    with %User{local: true} = blocked <- User.get_cached_by_ap_id(blocked),
         {:ok, %User{} = blocker} <- User.get_or_fetch_by_ap_id(blocker),
         {:ok, activity} <- ActivityPub.unblock(blocker, blocked, id, false) do
      User.unblock(blocker, blocked)
      {:ok, activity}
    else
      _e -> :error
    end
  end

  def handle_incoming(
        %{"type" => "Block", "object" => blocked, "actor" => blocker, "id" => id} = _data,
        _options
      ) do
    with %User{local: true} = blocked = User.get_cached_by_ap_id(blocked),
         {:ok, %User{} = blocker} = User.get_or_fetch_by_ap_id(blocker),
         {:ok, activity} <- ActivityPub.block(blocker, blocked, id, false) do
      User.unfollow(blocker, blocked)
      User.block(blocker, blocked)
      {:ok, activity}
    else
      _e -> :error
    end
  end

  def handle_incoming(
        %{
          "type" => "Undo",
          "object" => %{"type" => "Like", "object" => object_id},
          "actor" => _actor,
          "id" => id
        } = data,
        _options
      ) do
    with actor <- Containment.get_actor(data),
         {:ok, %User{} = actor} <- User.get_or_fetch_by_ap_id(actor),
         {:ok, object} <- get_obj_helper(object_id),
         {:ok, activity, _, _} <- ActivityPub.unlike(actor, object, id, false) do
      {:ok, activity}
    else
      _e -> :error
    end
  end

  # For Undos that don't have the complete object attached, try to find it in our database.
  def handle_incoming(
        %{
          "type" => "Undo",
          "object" => object
        } = activity,
        options
      )
      when is_binary(object) do
    with %Activity{data: data} <- Activity.get_by_ap_id(object) do
      activity
      |> Map.put("object", data)
      |> handle_incoming(options)
    else
      _e -> :error
    end
  end

  def handle_incoming(
        %{
          "type" => "Move",
          "actor" => origin_actor,
          "object" => origin_actor,
          "target" => target_actor
        },
        _options
      ) do
    with %User{} = origin_user <- User.get_cached_by_ap_id(origin_actor),
         {:ok, %User{} = target_user} <- User.get_or_fetch_by_ap_id(target_actor),
         true <- origin_actor in target_user.also_known_as do
      ActivityPub.move(origin_user, target_user, false)
    else
      _e -> :error
    end
  end

  def handle_incoming(_, _), do: :error

  @spec get_obj_helper(String.t(), Keyword.t()) :: {:ok, Object.t()} | nil
  def get_obj_helper(id, options \\ []) do
    case Object.normalize(id, true, options) do
      %Object{} = object -> {:ok, object}
      _ -> nil
    end
  end

  @spec get_embedded_obj_helper(String.t() | Object.t(), User.t()) :: {:ok, Object.t()} | nil
  def get_embedded_obj_helper(%{"attributedTo" => attributed_to, "id" => object_id} = data, %User{
        ap_id: ap_id
      })
      when attributed_to == ap_id do
    with {:ok, activity} <-
           handle_incoming(%{
             "type" => "Create",
             "to" => data["to"],
             "cc" => data["cc"],
             "actor" => attributed_to,
             "object" => data
           }) do
      {:ok, Object.normalize(activity)}
    else
      _ -> get_obj_helper(object_id)
    end
  end

  def get_embedded_obj_helper(object_id, _) do
    get_obj_helper(object_id)
  end

  def set_reply_to_uri(%{"inReplyTo" => in_reply_to} = object) when is_binary(in_reply_to) do
    with false <- String.starts_with?(in_reply_to, "http"),
         {:ok, %{data: replied_to_object}} <- get_obj_helper(in_reply_to) do
      Map.put(object, "inReplyTo", replied_to_object["external_url"] || in_reply_to)
    else
      _e -> object
    end
  end

  def set_reply_to_uri(obj), do: obj

  @doc """
  Serialized Mastodon-compatible `replies` collection containing _self-replies_.
  Based on Mastodon's ActivityPub::NoteSerializer#replies.
  """
  def set_replies(obj_data) do
    replies_uris =
      with limit when limit > 0 <-
             Pleroma.Config.get([:activitypub, :note_replies_output_limit], 0),
           %Object{} = object <- Object.get_cached_by_ap_id(obj_data["id"]) do
        object
        |> Object.self_replies()
        |> select([o], fragment("?->>'id'", o.data))
        |> limit(^limit)
        |> Repo.all()
      else
        _ -> []
      end

    set_replies(obj_data, replies_uris)
  end

  defp set_replies(obj, []) do
    obj
  end

  defp set_replies(obj, replies_uris) do
    replies_collection = %{
      "type" => "Collection",
      "items" => replies_uris
    }

    Map.merge(obj, %{"replies" => replies_collection})
  end

  def replies(%{"replies" => %{"first" => %{"items" => items}}}) when not is_nil(items) do
    items
  end

  def replies(%{"replies" => %{"items" => items}}) when not is_nil(items) do
    items
  end

  def replies(_), do: []

  # Prepares the object of an outgoing create activity.
  def prepare_object(object) do
    object
    |> set_sensitive
    |> add_hashtags
    |> add_mention_tags
    |> add_emoji_tags
    |> add_attributed_to
    |> prepare_attachments
    |> set_conversation
    |> set_reply_to_uri
    |> set_replies
    |> strip_internal_fields
    |> strip_internal_tags
    |> set_type
  end

  #  @doc
  #  """
  #  internal -> Mastodon
  #  """

  def prepare_outgoing(%{"type" => activity_type, "object" => object_id} = data)
      when activity_type in ["Create", "Listen"] do
    object =
      object_id
      |> Object.normalize()
      |> Map.get(:data)
      |> prepare_object

    data =
      data
      |> Map.put("object", object)
      |> Map.merge(Utils.make_json_ld_header())
      |> Map.delete("bcc")

    {:ok, data}
  end

  def prepare_outgoing(%{"type" => "Announce", "actor" => ap_id, "object" => object_id} = data) do
    object =
      object_id
      |> Object.normalize()

    data =
      if Visibility.is_private?(object) && object.data["actor"] == ap_id do
        data |> Map.put("object", object |> Map.get(:data) |> prepare_object)
      else
        data |> maybe_fix_object_url
      end

    data =
      data
      |> strip_internal_fields
      |> Map.merge(Utils.make_json_ld_header())
      |> Map.delete("bcc")

    {:ok, data}
  end

  # Mastodon Accept/Reject requires a non-normalized object containing the actor URIs,
  # because of course it does.
  def prepare_outgoing(%{"type" => "Accept"} = data) do
    with follow_activity <- Activity.normalize(data["object"]) do
      object = %{
        "actor" => follow_activity.actor,
        "object" => follow_activity.data["object"],
        "id" => follow_activity.data["id"],
        "type" => "Follow"
      }

      data =
        data
        |> Map.put("object", object)
        |> Map.merge(Utils.make_json_ld_header())

      {:ok, data}
    end
  end

  def prepare_outgoing(%{"type" => "Reject"} = data) do
    with follow_activity <- Activity.normalize(data["object"]) do
      object = %{
        "actor" => follow_activity.actor,
        "object" => follow_activity.data["object"],
        "id" => follow_activity.data["id"],
        "type" => "Follow"
      }

      data =
        data
        |> Map.put("object", object)
        |> Map.merge(Utils.make_json_ld_header())

      {:ok, data}
    end
  end

  def prepare_outgoing(%{"type" => _type} = data) do
    data =
      data
      |> strip_internal_fields
      |> maybe_fix_object_url
      |> Map.merge(Utils.make_json_ld_header())

    {:ok, data}
  end

  def maybe_fix_object_url(%{"object" => object} = data) when is_binary(object) do
    with false <- String.starts_with?(object, "http"),
         {:fetch, {:ok, relative_object}} <- {:fetch, get_obj_helper(object)},
         %{data: %{"external_url" => external_url}} when not is_nil(external_url) <-
           relative_object do
      Map.put(data, "object", external_url)
    else
      {:fetch, e} ->
        Logger.error("Couldn't fetch #{object} #{inspect(e)}")
        data

      _ ->
        data
    end
  end

  def maybe_fix_object_url(data), do: data

  def add_hashtags(object) do
    tags =
      (object["tag"] || [])
      |> Enum.map(fn
        # Expand internal representation tags into AS2 tags.
        tag when is_binary(tag) ->
          %{
            "href" => Pleroma.Web.Endpoint.url() <> "/tags/#{tag}",
            "name" => "##{tag}",
            "type" => "Hashtag"
          }

        # Do not process tags which are already AS2 tag objects.
        tag when is_map(tag) ->
          tag
      end)

    Map.put(object, "tag", tags)
  end

  def add_mention_tags(object) do
    mentions =
      object
      |> Utils.get_notified_from_object()
      |> Enum.map(&build_mention_tag/1)

    tags = object["tag"] || []

    Map.put(object, "tag", tags ++ mentions)
  end

  defp build_mention_tag(%{ap_id: ap_id, nickname: nickname} = _) do
    %{"type" => "Mention", "href" => ap_id, "name" => "@#{nickname}"}
  end

  def take_emoji_tags(%User{emoji: emoji}) do
    emoji
    |> Enum.flat_map(&Map.to_list/1)
    |> Enum.map(&build_emoji_tag/1)
  end

  # TODO: we should probably send mtime instead of unix epoch time for updated
  def add_emoji_tags(%{"emoji" => emoji} = object) do
    tags = object["tag"] || []

    out = Enum.map(emoji, &build_emoji_tag/1)

    Map.put(object, "tag", tags ++ out)
  end

  def add_emoji_tags(object), do: object

  defp build_emoji_tag({name, url}) do
    %{
      "icon" => %{"url" => url, "type" => "Image"},
      "name" => ":" <> name <> ":",
      "type" => "Emoji",
      "updated" => "1970-01-01T00:00:00Z",
      "id" => url
    }
  end

  def set_conversation(object) do
    Map.put(object, "conversation", object["context"])
  end

  def set_sensitive(object) do
    tags = object["tag"] || []
    Map.put(object, "sensitive", "nsfw" in tags)
  end

  def set_type(%{"type" => "Answer"} = object) do
    Map.put(object, "type", "Note")
  end

  def set_type(object), do: object

  def add_attributed_to(object) do
    attributed_to = object["attributedTo"] || object["actor"]
    Map.put(object, "attributedTo", attributed_to)
  end

  def prepare_attachments(object) do
    attachments =
      (object["attachment"] || [])
      |> Enum.map(fn data ->
        [%{"mediaType" => media_type, "href" => href} | _] = data["url"]
        %{"url" => href, "mediaType" => media_type, "name" => data["name"], "type" => "Document"}
      end)

    Map.put(object, "attachment", attachments)
  end

  def strip_internal_fields(object) do
    object
    |> Map.drop(Pleroma.Constants.object_internal_fields())
  end

  defp strip_internal_tags(%{"tag" => tags} = object) do
    tags = Enum.filter(tags, fn x -> is_map(x) end)

    Map.put(object, "tag", tags)
  end

  defp strip_internal_tags(object), do: object

  def perform(:user_upgrade, user) do
    # we pass a fake user so that the followers collection is stripped away
    old_follower_address = User.ap_followers(%User{nickname: user.nickname})

    from(
      a in Activity,
      where: ^old_follower_address in a.recipients,
      update: [
        set: [
          recipients:
            fragment(
              "array_replace(?,?,?)",
              a.recipients,
              ^old_follower_address,
              ^user.follower_address
            )
        ]
      ]
    )
    |> Repo.update_all([])
  end

  def upgrade_user_from_ap_id(ap_id) do
    with %User{local: false} = user <- User.get_cached_by_ap_id(ap_id),
         {:ok, data} <- ActivityPub.fetch_and_prepare_user_from_ap_id(ap_id),
         already_ap <- User.ap_enabled?(user),
         {:ok, user} <- upgrade_user(user, data) do
      if not already_ap do
        TransmogrifierWorker.enqueue("user_upgrade", %{"user_id" => user.id})
      end

      {:ok, user}
    else
      %User{} = user -> {:ok, user}
      e -> e
    end
  end

  defp upgrade_user(user, data) do
    user
    |> User.upgrade_changeset(data, true)
    |> User.update_and_set_cache()
  end

  def maybe_fix_user_url(%{"url" => url} = data) when is_map(url) do
    Map.put(data, "url", url["href"])
  end

  def maybe_fix_user_url(data), do: data

  def maybe_fix_user_object(data), do: maybe_fix_user_url(data)
end
