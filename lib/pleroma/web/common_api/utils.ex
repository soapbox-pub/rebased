# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI.Utils do
  alias Calendar.Strftime
  alias Comeonin.Pbkdf2
  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.Formatter
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.MediaProxy

  require Logger

  # This is a hack for twidere.
  def get_by_id_or_ap_id(id) do
    activity =
      Activity.get_by_id_with_object(id) || Activity.get_create_by_object_ap_id_with_object(id)

    activity &&
      if activity.data["type"] == "Create" do
        activity
      else
        Activity.get_create_by_object_ap_id_with_object(activity.data["object"])
      end
  end

  def get_replied_to_activity(""), do: nil

  def get_replied_to_activity(id) when not is_nil(id) do
    Activity.get_by_id(id)
  end

  def get_replied_to_activity(_), do: nil

  def attachments_from_ids(data) do
    if Map.has_key?(data, "descriptions") do
      attachments_from_ids_descs(data["media_ids"], data["descriptions"])
    else
      attachments_from_ids_no_descs(data["media_ids"])
    end
  end

  def attachments_from_ids_no_descs(ids) do
    Enum.map(ids || [], fn media_id ->
      Repo.get(Object, media_id).data
    end)
  end

  def attachments_from_ids_descs(ids, descs_str) do
    {_, descs} = Jason.decode(descs_str)

    Enum.map(ids || [], fn media_id ->
      Map.put(Repo.get(Object, media_id).data, "name", descs[media_id])
    end)
  end

  def to_for_user_and_mentions(user, mentions, inReplyTo, "public") do
    mentioned_users = Enum.map(mentions, fn {_, %{ap_id: ap_id}} -> ap_id end)

    to = ["https://www.w3.org/ns/activitystreams#Public" | mentioned_users]
    cc = [user.follower_address]

    if inReplyTo do
      {Enum.uniq([inReplyTo.data["actor"] | to]), cc}
    else
      {to, cc}
    end
  end

  def to_for_user_and_mentions(user, mentions, inReplyTo, "unlisted") do
    mentioned_users = Enum.map(mentions, fn {_, %{ap_id: ap_id}} -> ap_id end)

    to = [user.follower_address | mentioned_users]
    cc = ["https://www.w3.org/ns/activitystreams#Public"]

    if inReplyTo do
      {Enum.uniq([inReplyTo.data["actor"] | to]), cc}
    else
      {to, cc}
    end
  end

  def to_for_user_and_mentions(user, mentions, inReplyTo, "private") do
    {to, cc} = to_for_user_and_mentions(user, mentions, inReplyTo, "direct")
    {[user.follower_address | to], cc}
  end

  def to_for_user_and_mentions(_user, mentions, inReplyTo, "direct") do
    mentioned_users = Enum.map(mentions, fn {_, %{ap_id: ap_id}} -> ap_id end)

    if inReplyTo do
      {Enum.uniq([inReplyTo.data["actor"] | mentioned_users]), []}
    else
      {mentioned_users, []}
    end
  end

  def to_for_user_and_mentions(_user, _mentions, _inReplyTo, _), do: {[], []}

  def bcc_for_list(user, {:list, list_id}) do
    list = Pleroma.List.get(list_id, user)
    [list.ap_id]
  end

  def bcc_for_list(_, _), do: []

  def make_content_html(
        status,
        attachments,
        data,
        visibility
      ) do
    no_attachment_links =
      data
      |> Map.get("no_attachment_links", Config.get([:instance, :no_attachment_links]))
      |> Kernel.in([true, "true"])

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

  def make_context(%Activity{data: %{"context" => context}}), do: context
  def make_context(_), do: Utils.generate_context_id()

  def maybe_add_attachments(parsed, _attachments, true = _no_links), do: parsed

  def maybe_add_attachments({text, mentions, tags}, attachments, _no_links) do
    text = add_attachments(text, attachments)
    {text, mentions, tags}
  end

  def add_attachments(text, attachments) do
    attachment_text =
      Enum.map(attachments, fn
        %{"url" => [%{"href" => href} | _]} = attachment ->
          name = attachment["name"] || URI.decode(Path.basename(href))
          href = MediaProxy.url(href)
          "<a href=\"#{href}\" class='attachment'>#{shortname(name)}</a>"

        _ ->
          ""
      end)

    Enum.join([text | attachment_text], "<br>")
  end

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
        cw \\ nil,
        cc \\ []
      ) do
    object = %{
      "type" => "Note",
      "to" => to,
      "cc" => cc,
      "content" => content_html,
      "summary" => cw,
      "context" => context,
      "attachment" => attachments,
      "actor" => actor,
      "tag" => tags |> Enum.map(fn {_, tag} -> tag end) |> Enum.uniq()
    }

    with false <- is_nil(in_reply_to),
         %Object{} = in_reply_to_object <- Object.normalize(in_reply_to) do
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

  def to_masto_date(date) do
    try do
      date
      |> NaiveDateTime.from_iso8601!()
      |> NaiveDateTime.to_iso8601()
      |> String.replace(~r/(\.\d+)?$/, ".000Z", global: false)
    rescue
      _e -> ""
    end
  end

  defp shortname(name) do
    if String.length(name) < 30 do
      name
    else
      String.slice(name, 0..30) <> "…"
    end
  end

  def confirm_current_password(user, password) do
    with %User{local: true} = db_user <- User.get_cached_by_id(user.id),
         true <- Pbkdf2.checkpw(password, db_user.password_hash) do
      {:ok, db_user}
    else
      _ -> {:error, "Invalid password."}
    end
  end

  def emoji_from_profile(%{info: _info} = user) do
    (Formatter.get_emoji(user.bio) ++ Formatter.get_emoji(user.name))
    |> Enum.map(fn {shortcode, url, _} ->
      %{
        "type" => "Emoji",
        "icon" => %{"type" => "Image", "url" => "#{Endpoint.url()}#{url}"},
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

  def maybe_notify_mentioned_recipients(
        recipients,
        %Activity{data: %{"to" => _to, "type" => type} = data} = activity
      )
      when type == "Create" do
    object = Object.normalize(activity)

    object_data =
      cond do
        !is_nil(object) ->
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

  def maybe_extract_mentions(%{"tag" => tag}) do
    tag
    |> Enum.filter(fn x -> is_map(x) end)
    |> Enum.filter(fn x -> x["type"] == "Mention" end)
    |> Enum.map(fn x -> x["href"] end)
  end

  def maybe_extract_mentions(_), do: []

  def make_report_content_html(nil), do: {:ok, {nil, [], []}}

  def make_report_content_html(comment) do
    max_size = Pleroma.Config.get([:instance, :max_report_comment_size], 1000)

    if String.length(comment) <= max_size do
      {:ok, format_input(comment, "text/plain")}
    else
      {:error, "Comment must be up to #{max_size} characters"}
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
        {:error, "No such conversation"}
    end
  end
end
