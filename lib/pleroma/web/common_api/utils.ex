defmodule Pleroma.Web.CommonAPI.Utils do
  alias Pleroma.{Repo, Object, Formatter, User, Activity}
  alias Pleroma.Web.ActivityPub.Utils
  alias Calendar.Strftime

  # This is a hack for twidere.
  def get_by_id_or_ap_id(id) do
    activity = Repo.get(Activity, id) || Activity.get_create_activity_by_object_ap_id(id)
    if activity.data["type"] == "Create" do
      activity
    else
      Activity.get_create_activity_by_object_ap_id(activity.data["object"])
    end
  end

  def get_replied_to_activity(id) when not is_nil(id) do
    Repo.get(Activity, id)
  end
  def get_replied_to_activity(_), do: nil

  def attachments_from_ids(ids) do
    Enum.map(ids || [], fn (media_id) ->
      Repo.get(Object, media_id).data
    end)
  end

  def to_for_user_and_mentions(user, mentions, inReplyTo) do
    default_to = [
      user.follower_address,
      "https://www.w3.org/ns/activitystreams#Public"
    ]

    to = default_to ++ Enum.map(mentions, fn ({_, %{ap_id: ap_id}}) -> ap_id end)
    if inReplyTo do
      Enum.uniq([inReplyTo.data["actor"] | to])
    else
      to
    end
  end

  def make_content_html(status, mentions, attachments) do
    status
    |> format_input(mentions)
    |> add_attachments(attachments)
  end

  def make_context(%Activity{data: %{"context" => context}}), do: context
  def make_context(_), do: Utils.generate_context_id

  def add_attachments(text, attachments) do
    attachment_text = Enum.map(attachments, fn
      (%{"url" => [%{"href" => href} | _]}) ->
        name = URI.decode(Path.basename(href))
        "<a href=\"#{href}\" class='attachment'>#{shortname(name)}</a>"
      _ -> ""
    end)
    Enum.join([text | attachment_text], "<br>\n")
  end

  def format_input(text, mentions) do
    HtmlSanitizeEx.strip_tags(text)
    |> Formatter.linkify
    |> String.replace("\n", "<br>\n")
    |> add_user_links(mentions)
  end

  def add_user_links(text, mentions) do
    mentions = mentions
    |> Enum.sort_by(fn ({name, _}) -> -String.length(name) end)
    |> Enum.map(fn({name, user}) -> {name, user, Ecto.UUID.generate} end)

    # This replaces the mention with a unique reference first so it doesn't
    # contain parts of other replaced mentions. There probably is a better
    # solution for this...
    step_one = mentions
    |> Enum.reduce(text, fn ({match, _user, uuid}, text) ->
      String.replace(text, match, uuid)
    end)

    Enum.reduce(mentions, step_one, fn ({match, %User{ap_id: ap_id}, uuid}, text) ->
      short_match = String.split(match, "@") |> tl() |> hd()
      String.replace(text, uuid, "<a href='#{ap_id}'>@#{short_match}</a>")
    end)
  end

  def make_note_data(actor, to, context, content_html, attachments, inReplyTo, tags) do
      object = %{
        "type" => "Note",
        "to" => to,
        "content" => content_html,
        "context" => context,
        "attachment" => attachments,
        "actor" => actor,
        "tag" => tags |> Enum.map(fn ({_, tag}) -> tag end)
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
    with {:ok, date, _offset} <- date |> DateTime.from_iso8601 do
      format_asctime(date)
    else _e ->
        ""
    end
  end

  defp shortname(name) do
    if String.length(name) < 30 do
      name
    else
      String.slice(name, 0..30) <> "…"
    end
  end
end
