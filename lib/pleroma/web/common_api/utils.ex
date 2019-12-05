# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI.Utils do
  import Pleroma.Web.Gettext
  import Pleroma.Web.ControllerHelper, only: [truthy_param?: 1]

  alias Calendar.Strftime
  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.Conversation.Participation
  alias Pleroma.Emoji
  alias Pleroma.Formatter
  alias Pleroma.Object
  alias Pleroma.Plugs.AuthenticationPlug
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.MediaProxy

  require Logger
  require Pleroma.Constants

  # This is a hack for twidere.
  def get_by_id_or_ap_id(id) do
    activity =
      with true <- FlakeId.flake_id?(id),
           %Activity{} = activity <- Activity.get_by_id_with_object(id) do
        activity
      else
        _ -> Activity.get_create_by_object_ap_id_with_object(id)
      end

    activity &&
      if activity.data["type"] == "Create" do
        activity
      else
        Activity.get_create_by_object_ap_id_with_object(activity.data["object"])
      end
  end

  def attachments_from_ids(%{"media_ids" => ids, "descriptions" => desc} = _) do
    attachments_from_ids_descs(ids, desc)
  end

  def attachments_from_ids(%{"media_ids" => ids} = _) do
    attachments_from_ids_no_descs(ids)
  end

  def attachments_from_ids(_), do: []

  def attachments_from_ids_no_descs([]), do: []

  def attachments_from_ids_no_descs(ids) do
    Enum.map(ids, fn media_id ->
      case Repo.get(Object, media_id) do
        %Object{data: data} = _ -> data
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)
  end

  def attachments_from_ids_descs([], _), do: []

  def attachments_from_ids_descs(ids, descs_str) do
    {_, descs} = Jason.decode(descs_str)

    Enum.map(ids, fn media_id ->
      case Repo.get(Object, media_id) do
        %Object{data: data} = _ ->
          Map.put(data, "name", descs[media_id])

        _ ->
          nil
      end
    end)
    |> Enum.filter(& &1)
  end

  @spec get_to_and_cc(
          User.t(),
          list(String.t()),
          Activity.t() | nil,
          String.t(),
          Participation.t() | nil
        ) :: {list(String.t()), list(String.t())}

  def get_to_and_cc(_, _, _, _, %Participation{} = participation) do
    participation = Repo.preload(participation, :recipients)
    {Enum.map(participation.recipients, & &1.ap_id), []}
  end

  def get_to_and_cc(user, mentioned_users, inReplyTo, "public", _) do
    to = [Pleroma.Constants.as_public() | mentioned_users]
    cc = [user.follower_address]

    if inReplyTo do
      {Enum.uniq([inReplyTo.data["actor"] | to]), cc}
    else
      {to, cc}
    end
  end

  def get_to_and_cc(user, mentioned_users, inReplyTo, "unlisted", _) do
    to = [user.follower_address | mentioned_users]
    cc = [Pleroma.Constants.as_public()]

    if inReplyTo do
      {Enum.uniq([inReplyTo.data["actor"] | to]), cc}
    else
      {to, cc}
    end
  end

  def get_to_and_cc(user, mentioned_users, inReplyTo, "private", _) do
    {to, cc} = get_to_and_cc(user, mentioned_users, inReplyTo, "direct", nil)
    {[user.follower_address | to], cc}
  end

  def get_to_and_cc(_user, mentioned_users, inReplyTo, "direct", _) do
    if inReplyTo do
      {Enum.uniq([inReplyTo.data["actor"] | mentioned_users]), []}
    else
      {mentioned_users, []}
    end
  end

  def get_to_and_cc(_user, mentions, _inReplyTo, {:list, _}, _), do: {mentions, []}

  def get_addressed_users(_, to) when is_list(to) do
    User.get_ap_ids_by_nicknames(to)
  end

  def get_addressed_users(mentioned_users, _), do: mentioned_users

  def maybe_add_list_data(activity_params, user, {:list, list_id}) do
    case Pleroma.List.get(list_id, user) do
      %Pleroma.List{} = list ->
        activity_params
        |> put_in([:additional, "bcc"], [list.ap_id])
        |> put_in([:additional, "listMessage"], list.ap_id)
        |> put_in([:object, "listMessage"], list.ap_id)

      _ ->
        activity_params
    end
  end

  def maybe_add_list_data(activity_params, _, _), do: activity_params

  def make_poll_data(%{"poll" => %{"expires_in" => expires_in}} = data)
      when is_binary(expires_in) do
    # In some cases mastofe sends out strings instead of integers
    data
    |> put_in(["poll", "expires_in"], String.to_integer(expires_in))
    |> make_poll_data()
  end

  def make_poll_data(%{"poll" => %{"options" => options, "expires_in" => expires_in}} = data)
      when is_list(options) do
    limits = Pleroma.Config.get([:instance, :poll_limits])

    with :ok <- validate_poll_expiration(expires_in, limits),
         :ok <- validate_poll_options_amount(options, limits),
         :ok <- validate_poll_options_length(options, limits) do
      {option_notes, emoji} =
        Enum.map_reduce(options, %{}, fn option, emoji ->
          note = %{
            "name" => option,
            "type" => "Note",
            "replies" => %{"type" => "Collection", "totalItems" => 0}
          }

          {note, Map.merge(emoji, Emoji.Formatter.get_emoji_map(option))}
        end)

      end_time =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(expires_in)
        |> NaiveDateTime.to_iso8601()

      key = if truthy_param?(data["poll"]["multiple"]), do: "anyOf", else: "oneOf"
      poll = %{"type" => "Question", key => option_notes, "closed" => end_time}

      {:ok, {poll, emoji}}
    end
  end

  def make_poll_data(%{"poll" => poll}) when is_map(poll) do
    {:error, "Invalid poll"}
  end

  def make_poll_data(_data) do
    {:ok, {%{}, %{}}}
  end

  defp validate_poll_options_amount(options, %{max_options: max_options}) do
    if Enum.count(options) > max_options do
      {:error, "Poll can't contain more than #{max_options} options"}
    else
      :ok
    end
  end

  defp validate_poll_options_length(options, %{max_option_chars: max_option_chars}) do
    if Enum.any?(options, &(String.length(&1) > max_option_chars)) do
      {:error, "Poll options cannot be longer than #{max_option_chars} characters each"}
    else
      :ok
    end
  end

  defp validate_poll_expiration(expires_in, %{min_expiration: min, max_expiration: max}) do
    cond do
      expires_in > max -> {:error, "Expiration date is too far in the future"}
      expires_in < min -> {:error, "Expiration date is too soon"}
      true -> :ok
    end
  end

  def make_content_html(
        status,
        attachments,
        data,
        visibility
      ) do
    no_attachment_links =
      data
      |> Map.get("no_attachment_links", Config.get([:instance, :no_attachment_links]))
      |> truthy_param?()

    content_type = get_content_type(data["content_type"])

    options =
      if visibility == "direct" && Config.get([:instance, :safe_dm_mentions]) do
        [safe_mention: true]
      else
        []
      end

    status
    |> format_input(content_type, options)
    |> maybe_add_attachments(attachments, no_attachment_links)
    |> maybe_add_nsfw_tag(data)
  end

  defp get_content_type(content_type) do
    if Enum.member?(Config.get([:instance, :allowed_post_formats]), content_type) do
      content_type
    else
      "text/plain"
    end
  end

  defp maybe_add_nsfw_tag({text, mentions, tags}, %{"sensitive" => sensitive})
       when sensitive in [true, "True", "true", "1"] do
    {text, mentions, [{"#nsfw", "nsfw"} | tags]}
  end

  defp maybe_add_nsfw_tag(data, _), do: data

  def make_context(_, %Participation{} = participation) do
    Repo.preload(participation, :conversation).conversation.ap_id
  end

  def make_context(%Activity{data: %{"context" => context}}, _), do: context
  def make_context(_, _), do: Utils.generate_context_id()

  def maybe_add_attachments(parsed, _attachments, true = _no_links), do: parsed

  def maybe_add_attachments({text, mentions, tags}, attachments, _no_links) do
    text = add_attachments(text, attachments)
    {text, mentions, tags}
  end

  def add_attachments(text, attachments) do
    attachment_text = Enum.map(attachments, &build_attachment_link/1)
    Enum.join([text | attachment_text], "<br>")
  end

  defp build_attachment_link(%{"url" => [%{"href" => href} | _]} = attachment) do
    name = attachment["name"] || URI.decode(Path.basename(href))
    href = MediaProxy.url(href)
    "<a href=\"#{href}\" class='attachment'>#{shortname(name)}</a>"
  end

  defp build_attachment_link(_), do: ""

  def format_input(text, format, options \\ [])

  @doc """
  Formatting text to plain text.
  """
  def format_input(text, "text/plain", options) do
    text
    |> Formatter.html_escape("text/plain")
    |> Formatter.linkify(options)
    |> (fn {text, mentions, tags} ->
          {String.replace(text, ~r/\r?\n/, "<br>"), mentions, tags}
        end).()
  end

  @doc """
  Formatting text as BBCode.
  """
  def format_input(text, "text/bbcode", options) do
    text
    |> String.replace(~r/\r/, "")
    |> Formatter.html_escape("text/plain")
    |> BBCode.to_html()
    |> (fn {:ok, html} -> html end).()
    |> Formatter.linkify(options)
  end

  @doc """
  Formatting text to html.
  """
  def format_input(text, "text/html", options) do
    text
    |> Formatter.html_escape("text/html")
    |> Formatter.linkify(options)
  end

  @doc """
  Formatting text to markdown.
  """
  def format_input(text, "text/markdown", options) do
    text
    |> Formatter.mentions_escape(options)
    |> Earmark.as_html!()
    |> Formatter.linkify(options)
    |> Formatter.html_escape("text/html")
  end

  def make_note_data(
        actor,
        to,
        context,
        content_html,
        attachments,
        in_reply_to,
        tags,
        summary \\ nil,
        cc \\ [],
        sensitive \\ false,
        extra_params \\ %{}
      ) do
    %{
      "type" => "Note",
      "to" => to,
      "cc" => cc,
      "content" => content_html,
      "summary" => summary,
      "sensitive" => truthy_param?(sensitive),
      "context" => context,
      "attachment" => attachments,
      "actor" => actor,
      "tag" => Keyword.values(tags) |> Enum.uniq()
    }
    |> add_in_reply_to(in_reply_to)
    |> Map.merge(extra_params)
  end

  defp add_in_reply_to(object, nil), do: object

  defp add_in_reply_to(object, in_reply_to) do
    with %Object{} = in_reply_to_object <- Object.normalize(in_reply_to) do
      Map.put(object, "inReplyTo", in_reply_to_object.data["id"])
    else
      _ -> object
    end
  end

  def format_naive_asctime(date) do
    date |> DateTime.from_naive!("Etc/UTC") |> format_asctime
  end

  def format_asctime(date) do
    Strftime.strftime!(date, "%a %b %d %H:%M:%S %z %Y")
  end

  def date_to_asctime(date) when is_binary(date) do
    with {:ok, date, _offset} <- DateTime.from_iso8601(date) do
      format_asctime(date)
    else
      _e ->
        Logger.warn("Date #{date} in wrong format, must be ISO 8601")
        ""
    end
  end

  def date_to_asctime(date) do
    Logger.warn("Date #{date} in wrong format, must be ISO 8601")
    ""
  end

  def to_masto_date(%NaiveDateTime{} = date) do
    date
    |> NaiveDateTime.to_iso8601()
    |> String.replace(~r/(\.\d+)?$/, ".000Z", global: false)
  end

  def to_masto_date(date) when is_binary(date) do
    with {:ok, date} <- NaiveDateTime.from_iso8601(date) do
      to_masto_date(date)
    else
      _ -> ""
    end
  end

  def to_masto_date(_), do: ""

  defp shortname(name) do
    if String.length(name) < 30 do
      name
    else
      String.slice(name, 0..30) <> "…"
    end
  end

  def confirm_current_password(user, password) do
    with %User{local: true} = db_user <- User.get_cached_by_id(user.id),
         true <- AuthenticationPlug.checkpw(password, db_user.password_hash) do
      {:ok, db_user}
    else
      _ -> {:error, dgettext("errors", "Invalid password.")}
    end
  end

  def emoji_from_profile(%User{bio: bio, name: name}) do
    [bio, name]
    |> Enum.map(&Emoji.Formatter.get_emoji/1)
    |> Enum.concat()
    |> Enum.map(fn {shortcode, %Emoji{file: path}} ->
      %{
        "type" => "Emoji",
        "icon" => %{"type" => "Image", "url" => "#{Endpoint.url()}#{path}"},
        "name" => ":#{shortcode}:"
      }
    end)
  end

  def maybe_notify_to_recipients(
        recipients,
        %Activity{data: %{"to" => to, "type" => _type}} = _activity
      ) do
    recipients ++ to
  end

  def maybe_notify_to_recipients(recipients, _), do: recipients

  def maybe_notify_mentioned_recipients(
        recipients,
        %Activity{data: %{"to" => _to, "type" => type} = data} = activity
      )
      when type == "Create" do
    object = Object.normalize(activity)

    object_data =
      cond do
        not is_nil(object) ->
          object.data

        is_map(data["object"]) ->
          data["object"]

        true ->
          %{}
      end

    tagged_mentions = maybe_extract_mentions(object_data)

    recipients ++ tagged_mentions
  end

  def maybe_notify_mentioned_recipients(recipients, _), do: recipients

  # Do not notify subscribers if author is making a reply
  def maybe_notify_subscribers(recipients, %Activity{
        object: %Object{data: %{"inReplyTo" => _ap_id}}
      }) do
    recipients
  end

  def maybe_notify_subscribers(
        recipients,
        %Activity{data: %{"actor" => actor, "type" => type}} = activity
      )
      when type == "Create" do
    with %User{} = user <- User.get_cached_by_ap_id(actor) do
      subscriber_ids =
        user
        |> User.subscribers()
        |> Enum.filter(&Visibility.visible_for_user?(activity, &1))
        |> Enum.map(& &1.ap_id)

      recipients ++ subscriber_ids
    end
  end

  def maybe_notify_subscribers(recipients, _), do: recipients

  def maybe_notify_followers(recipients, %Activity{data: %{"type" => "Move"}} = activity) do
    with %User{} = user <- User.get_cached_by_ap_id(activity.actor) do
      user
      |> User.get_followers()
      |> Enum.map(& &1.ap_id)
      |> Enum.concat(recipients)
    end
  end

  def maybe_notify_followers(recipients, _), do: recipients

  def maybe_extract_mentions(%{"tag" => tag}) do
    tag
    |> Enum.filter(fn x -> is_map(x) && x["type"] == "Mention" end)
    |> Enum.map(fn x -> x["href"] end)
    |> Enum.uniq()
  end

  def maybe_extract_mentions(_), do: []

  def make_report_content_html(nil), do: {:ok, {nil, [], []}}

  def make_report_content_html(comment) do
    max_size = Pleroma.Config.get([:instance, :max_report_comment_size], 1000)

    if String.length(comment) <= max_size do
      {:ok, format_input(comment, "text/plain")}
    else
      {:error,
       dgettext("errors", "Comment must be up to %{max_size} characters", max_size: max_size)}
    end
  end

  def get_report_statuses(%User{ap_id: actor}, %{"status_ids" => status_ids}) do
    {:ok, Activity.all_by_actor_and_id(actor, status_ids)}
  end

  def get_report_statuses(_, _), do: {:ok, nil}

  # DEPRECATED mostly, context objects are now created at insertion time.
  def context_to_conversation_id(context) do
    with %Object{id: id} <- Object.get_cached_by_ap_id(context) do
      id
    else
      _e ->
        changeset = Object.context_mapping(context)

        case Repo.insert(changeset) do
          {:ok, %{id: id}} ->
            id

          # This should be solved by an upsert, but it seems ecto
          # has problems accessing the constraint inside the jsonb.
          {:error, _} ->
            Object.get_cached_by_ap_id(context).id
        end
    end
  end

  def conversation_id_to_context(id) do
    with %Object{data: %{"id" => context}} <- Repo.get(Object, id) do
      context
    else
      _e ->
        {:error, dgettext("errors", "No such conversation")}
    end
  end

  def make_answer_data(%User{ap_id: ap_id}, object, name) do
    %{
      "type" => "Answer",
      "actor" => ap_id,
      "cc" => [object.data["actor"]],
      "to" => [],
      "name" => name,
      "inReplyTo" => object.data["id"]
    }
  end

  def validate_character_limit("" = _full_payload, [] = _attachments) do
    {:error, dgettext("errors", "Cannot post an empty status without attachments")}
  end

  def validate_character_limit(full_payload, _attachments) do
    limit = Pleroma.Config.get([:instance, :limit])
    length = String.length(full_payload)

    if length < limit do
      :ok
    else
      {:error, dgettext("errors", "The status is over the character limit")}
    end
  end
end
