# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI.Utils do
  alias Calendar.Strftime
  alias Comeonin.Pbkdf2
  alias Pleroma.Activity
  alias Pleroma.Formatter
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.MediaProxy
  alias Pleroma.Web.ActivityPub.Utils

  # This is a hack for twidere.
  def get_by_id_or_ap_id(id) do
    activity = Repo.get(Activity, id) || Activity.get_create_by_object_ap_id(id)

    activity &&
      if activity.data["type"] == "Create" do
        activity
      else
        Activity.get_create_by_object_ap_id(activity.data["object"])
      end
  end

  def get_replied_to_activity(""), do: nil

  def get_replied_to_activity(id) when not is_nil(id) do
    Repo.get(Activity, id)
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

  def make_content_html(
        status,
        mentions,
        attachments,
        tags,
        content_type,
        no_attachment_links \\ false
      ) do
    status
    |> format_input(mentions, tags, content_type)
    |> maybe_add_attachments(attachments, no_attachment_links)
  end

  def make_context(%Activity{data: %{"context" => context}}), do: context
  def make_context(_), do: Utils.generate_context_id()

  def maybe_add_attachments(text, _attachments, true = _no_links), do: text

  def maybe_add_attachments(text, attachments, _no_links) do
    add_attachments(text, attachments)
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

  def format_input(text, mentions, tags, format, options \\ [])

  @doc """
  Formatting text to plain text.
  """
  def format_input(text, mentions, tags, "text/plain", options) do
    text
    |> Formatter.html_escape("text/plain")
    |> String.replace(~r/\r?\n/, "<br>")
    |> (&{[], &1}).()
    |> Formatter.add_links()
    |> Formatter.add_user_links(mentions, options[:user_links] || [])
    |> Formatter.add_hashtag_links(tags)
    |> Formatter.finalize()
  end

  @doc """
  Formatting text to html.
  """
  def format_input(text, mentions, _tags, "text/html", options) do
    text
    |> Formatter.html_escape("text/html")
    |> (&{[], &1}).()
    |> Formatter.add_user_links(mentions, options[:user_links] || [])
    |> Formatter.finalize()
  end

  @doc """
  Formatting text to markdown.
  """
  def format_input(text, mentions, tags, "text/markdown", options) do
    text
    |> Formatter.mentions_escape(mentions)
    |> Earmark.as_html!()
    |> Formatter.html_escape("text/html")
    |> (&{[], &1}).()
    |> Formatter.add_user_links(mentions, options[:user_links] || [])
    |> Formatter.add_hashtag_links(tags)
    |> Formatter.finalize()
  end

  def add_tag_links(text, tags) do
    tags =
      tags
      |> Enum.sort_by(fn {tag, _} -> -String.length(tag) end)

    Enum.reduce(tags, text, fn {full, tag}, text ->
      url = "<a href='#{Web.base_url()}/tag/#{tag}' rel='tag'>##{tag}</a>"
      String.replace(text, full, url)
    end)
  end

  def make_note_data(
        actor,
        to,
        context,
        content_html,
        attachments,
        inReplyTo,
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

    if inReplyTo do
      object
      |> Map.put("inReplyTo", inReplyTo.data["object"]["id"])
      |> Map.put("inReplyToStatusId", inReplyTo.id)
    else
      object
    end
  end

  def format_naive_asctime(date) do
    date |> DateTime.from_naive!("Etc/UTC") |> format_asctime
  end

  def format_asctime(date) do
    Strftime.strftime!(date, "%a %b %d %H:%M:%S %z %Y")
  end

  def date_to_asctime(date) do
    with {:ok, date, _offset} <- date |> DateTime.from_iso8601() do
      format_asctime(date)
    else
      _e ->
        ""
    end
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
    with %User{local: true} = db_user <- Repo.get(User, user.id),
         true <- Pbkdf2.checkpw(password, db_user.password_hash) do
      {:ok, db_user}
    else
      _ -> {:error, "Invalid password."}
    end
  end

  def emoji_from_profile(%{info: _info} = user) do
    (Formatter.get_emoji(user.bio) ++ Formatter.get_emoji(user.name))
    |> Enum.map(fn {shortcode, url} ->
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
        %Activity{data: %{"to" => _to, "type" => type} = data} = _activity
      )
      when type == "Create" do
    object = Object.normalize(data["object"])

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

  def maybe_extract_mentions(%{"tag" => tag}) do
    tag
    |> Enum.filter(fn x -> is_map(x) end)
    |> Enum.filter(fn x -> x["type"] == "Mention" end)
    |> Enum.map(fn x -> x["href"] end)
  end

  def maybe_extract_mentions(_), do: []
end
