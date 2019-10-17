# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OStatus do
  import Pleroma.Web.XML
  require Logger

  alias Pleroma.Activity
  alias Pleroma.HTTP
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.OStatus.DeleteHandler
  alias Pleroma.Web.OStatus.FollowHandler
  alias Pleroma.Web.OStatus.NoteHandler
  alias Pleroma.Web.OStatus.UnfollowHandler
  alias Pleroma.Web.WebFinger

  def is_representable?(%Activity{} = activity) do
    object = Object.normalize(activity)

    cond do
      is_nil(object) ->
        false

      Visibility.is_public?(activity) && object.data["type"] == "Note" ->
        true

      true ->
        false
    end
  end

  def feed_path(user), do: "#{user.ap_id}/feed.atom"

  def pubsub_path(user), do: "#{Web.base_url()}/push/hub/#{user.nickname}"

  def salmon_path(user), do: "#{user.ap_id}/salmon"

  def remote_follow_path, do: "#{Web.base_url()}/ostatus_subscribe?acct={uri}"

  def handle_incoming(xml_string, options \\ []) do
    with doc when doc != :error <- parse_document(xml_string) do
      with {:ok, actor_user} <- find_make_or_update_actor(doc),
           do: Pleroma.Instances.set_reachable(actor_user.ap_id)

      entries = :xmerl_xpath.string('//entry', doc)

      activities =
        Enum.map(entries, fn entry ->
          {:xmlObj, :string, object_type} =
            :xmerl_xpath.string('string(/entry/activity:object-type[1])', entry)

          {:xmlObj, :string, verb} = :xmerl_xpath.string('string(/entry/activity:verb[1])', entry)
          Logger.debug("Handling #{verb}")

          try do
            case verb do
              'http://activitystrea.ms/schema/1.0/delete' ->
                with {:ok, activity} <- DeleteHandler.handle_delete(entry, doc), do: activity

              'http://activitystrea.ms/schema/1.0/follow' ->
                with {:ok, activity} <- FollowHandler.handle(entry, doc), do: activity

              'http://activitystrea.ms/schema/1.0/unfollow' ->
                with {:ok, activity} <- UnfollowHandler.handle(entry, doc), do: activity

              'http://activitystrea.ms/schema/1.0/share' ->
                with {:ok, activity, retweeted_activity} <- handle_share(entry, doc),
                     do: [activity, retweeted_activity]

              'http://activitystrea.ms/schema/1.0/favorite' ->
                with {:ok, activity, favorited_activity} <- handle_favorite(entry, doc),
                     do: [activity, favorited_activity]

              _ ->
                case object_type do
                  'http://activitystrea.ms/schema/1.0/note' ->
                    with {:ok, activity} <- NoteHandler.handle_note(entry, doc, options),
                         do: activity

                  'http://activitystrea.ms/schema/1.0/comment' ->
                    with {:ok, activity} <- NoteHandler.handle_note(entry, doc, options),
                         do: activity

                  _ ->
                    Logger.error("Couldn't parse incoming document")
                    nil
                end
            end
          rescue
            e ->
              Logger.error("Error occured while handling activity")
              Logger.error(xml_string)
              Logger.error(inspect(e))
              nil
          end
        end)
        |> Enum.filter(& &1)

      {:ok, activities}
    else
      _e -> {:error, []}
    end
  end

  def make_share(entry, doc, retweeted_activity) do
    with {:ok, actor} <- find_make_or_update_actor(doc),
         %Object{} = object <- Object.normalize(retweeted_activity),
         id when not is_nil(id) <- string_from_xpath("/entry/id", entry),
         {:ok, activity, _object} = ActivityPub.announce(actor, object, id, false) do
      {:ok, activity}
    end
  end

  def handle_share(entry, doc) do
    with {:ok, retweeted_activity} <- get_or_build_object(entry),
         {:ok, activity} <- make_share(entry, doc, retweeted_activity) do
      {:ok, activity, retweeted_activity}
    else
      e -> {:error, e}
    end
  end

  def make_favorite(entry, doc, favorited_activity) do
    with {:ok, actor} <- find_make_or_update_actor(doc),
         %Object{} = object <- Object.normalize(favorited_activity),
         id when not is_nil(id) <- string_from_xpath("/entry/id", entry),
         {:ok, activity, _object} = ActivityPub.like(actor, object, id, false) do
      {:ok, activity}
    end
  end

  def get_or_build_object(entry) do
    with {:ok, activity} <- get_or_try_fetching(entry) do
      {:ok, activity}
    else
      _e ->
        with [object] <- :xmerl_xpath.string('/entry/activity:object', entry) do
          NoteHandler.handle_note(object, object)
        end
    end
  end

  def get_or_try_fetching(entry) do
    Logger.debug("Trying to get entry from db")

    with id when not is_nil(id) <- string_from_xpath("//activity:object[1]/id", entry),
         %Activity{} = activity <- Activity.get_create_by_object_ap_id_with_object(id) do
      {:ok, activity}
    else
      _ ->
        Logger.debug("Couldn't get, will try to fetch")

        with href when not is_nil(href) <-
               string_from_xpath("//activity:object[1]/link[@type=\"text/html\"]/@href", entry),
             {:ok, [favorited_activity]} <- fetch_activity_from_url(href) do
          {:ok, favorited_activity}
        else
          e -> Logger.debug("Couldn't find href: #{inspect(e)}")
        end
    end
  end

  def handle_favorite(entry, doc) do
    with {:ok, favorited_activity} <- get_or_try_fetching(entry),
         {:ok, activity} <- make_favorite(entry, doc, favorited_activity) do
      {:ok, activity, favorited_activity}
    else
      e -> {:error, e}
    end
  end

  def get_attachments(entry) do
    :xmerl_xpath.string('/entry/link[@rel="enclosure"]', entry)
    |> Enum.map(fn enclosure ->
      with href when not is_nil(href) <- string_from_xpath("/link/@href", enclosure),
           type when not is_nil(type) <- string_from_xpath("/link/@type", enclosure) do
        %{
          "type" => "Attachment",
          "url" => [
            %{
              "type" => "Link",
              "mediaType" => type,
              "href" => href
            }
          ]
        }
      end
    end)
    |> Enum.filter(& &1)
  end

  @doc """
    Gets the content from a an entry.
  """
  def get_content(entry) do
    string_from_xpath("//content", entry)
  end

  @doc """
    Get the cw that mastodon uses.
  """
  def get_cw(entry) do
    case string_from_xpath("/*/summary", entry) do
      cw when not is_nil(cw) -> cw
      _ -> nil
    end
  end

  def get_tags(entry) do
    :xmerl_xpath.string('//category', entry)
    |> Enum.map(fn category -> string_from_xpath("/category/@term", category) end)
    |> Enum.filter(& &1)
    |> Enum.map(&String.downcase/1)
  end

  def maybe_update(doc, user) do
    case string_from_xpath("//author[1]/ap_enabled", doc) do
      "true" ->
        Transmogrifier.upgrade_user_from_ap_id(user.ap_id)

      _ ->
        maybe_update_ostatus(doc, user)
    end
  end

  def maybe_update_ostatus(doc, user) do
    old_data = Map.take(user, [:bio, :avatar, :name])

    with false <- user.local,
         avatar <- make_avatar_object(doc),
         bio <- string_from_xpath("//author[1]/summary", doc),
         name <- string_from_xpath("//author[1]/poco:displayName", doc),
         new_data <- %{
           avatar: avatar || old_data.avatar,
           name: name || old_data.name,
           bio: bio || old_data.bio
         },
         false <- new_data == old_data do
      change = Ecto.Changeset.change(user, new_data)
      User.update_and_set_cache(change)
    else
      _ ->
        {:ok, user}
    end
  end

  def find_make_or_update_actor(doc) do
    uri = string_from_xpath("//author/uri[1]", doc)

    with {:ok, %User{} = user} <- find_or_make_user(uri),
         {:ap_enabled, false} <- {:ap_enabled, User.ap_enabled?(user)} do
      maybe_update(doc, user)
    else
      {:ap_enabled, true} ->
        {:error, :invalid_protocol}

      _ ->
        {:error, :unknown_user}
    end
  end

  @spec find_or_make_user(String.t()) :: {:ok, User.t()}
  def find_or_make_user(uri) do
    case User.get_by_ap_id(uri) do
      %User{} = user -> {:ok, user}
      _ -> make_user(uri)
    end
  end

  @spec make_user(String.t(), boolean()) :: {:ok, User.t()} | {:error, any()}
  def make_user(uri, update \\ false) do
    with {:ok, info} <- gather_user_info(uri) do
      with false <- update,
           %User{} = user <- User.get_cached_by_ap_id(info["uri"]) do
        {:ok, user}
      else
        _e -> User.insert_or_update_user(build_user_data(info))
      end
    end
  end

  defp build_user_data(info) do
    %{
      name: info["name"],
      nickname: info["nickname"] <> "@" <> info["host"],
      ap_id: info["uri"],
      info: info,
      avatar: info["avatar"],
      bio: info["bio"]
    }
  end

  # TODO: Just takes the first one for now.
  def make_avatar_object(author_doc, rel \\ "avatar") do
    href = string_from_xpath("//author[1]/link[@rel=\"#{rel}\"]/@href", author_doc)
    type = string_from_xpath("//author[1]/link[@rel=\"#{rel}\"]/@type", author_doc)

    if href do
      %{
        "type" => "Image",
        "url" => [%{"type" => "Link", "mediaType" => type, "href" => href}]
      }
    else
      nil
    end
  end

  @spec gather_user_info(String.t()) :: {:ok, map()} | {:error, any()}
  def gather_user_info(username) do
    with {:ok, webfinger_data} <- WebFinger.finger(username) do
      data =
        webfinger_data
        |> Map.put("fqn", username)

      {:ok, data}
    else
      e ->
        Logger.debug(fn -> "Couldn't gather info for #{username}" end)
        {:error, e}
    end
  end

  # Regex-based 'parsing' so we don't have to pull in a full html parser
  # It's a hack anyway. Maybe revisit this in the future
  @mastodon_regex ~r/<link href='(.*)' rel='alternate' type='application\/atom\+xml'>/
  @gs_regex ~r/<link title=.* href="(.*)" type="application\/atom\+xml" rel="alternate">/
  @gs_classic_regex ~r/<link rel="alternate" href="(.*)" type="application\/atom\+xml" title=.*>/
  def get_atom_url(body) do
    cond do
      Regex.match?(@mastodon_regex, body) ->
        [[_, match]] = Regex.scan(@mastodon_regex, body)
        {:ok, match}

      Regex.match?(@gs_regex, body) ->
        [[_, match]] = Regex.scan(@gs_regex, body)
        {:ok, match}

      Regex.match?(@gs_classic_regex, body) ->
        [[_, match]] = Regex.scan(@gs_classic_regex, body)
        {:ok, match}

      true ->
        Logger.debug(fn -> "Couldn't find Atom link in #{inspect(body)}" end)
        {:error, "Couldn't find the Atom link"}
    end
  end

  def fetch_activity_from_atom_url(url, options \\ []) do
    with true <- String.starts_with?(url, "http"),
         {:ok, %{body: body, status: code}} when code in 200..299 <-
           HTTP.get(url, [{:Accept, "application/atom+xml"}]) do
      Logger.debug("Got document from #{url}, handling...")
      handle_incoming(body, options)
    else
      e ->
        Logger.debug("Couldn't get #{url}: #{inspect(e)}")
        e
    end
  end

  def fetch_activity_from_html_url(url, options \\ []) do
    Logger.debug("Trying to fetch #{url}")

    with true <- String.starts_with?(url, "http"),
         {:ok, %{body: body}} <- HTTP.get(url, []),
         {:ok, atom_url} <- get_atom_url(body) do
      fetch_activity_from_atom_url(atom_url, options)
    else
      e ->
        Logger.debug("Couldn't get #{url}: #{inspect(e)}")
        e
    end
  end

  def fetch_activity_from_url(url, options \\ []) do
    with {:ok, [_ | _] = activities} <- fetch_activity_from_atom_url(url, options) do
      {:ok, activities}
    else
      _e -> fetch_activity_from_html_url(url, options)
    end
  rescue
    e ->
      Logger.debug("Couldn't get #{url}: #{inspect(e)}")
      {:error, "Couldn't get #{url}: #{inspect(e)}"}
  end
end
