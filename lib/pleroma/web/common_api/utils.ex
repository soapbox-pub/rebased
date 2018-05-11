defmodule Pleroma.Web.CommonAPI.Utils do
  alias Pleroma.{Repo, Object, Formatter, Activity}
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.User
  alias Calendar.Strftime
  alias Comeonin.Pbkdf2

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
    Enum.map(ids || [], fn media_id ->
      Repo.get(Object, media_id).data
    end)
  end

  def to_for_user_and_mentions(user, mentions, inReplyTo, "public") do
    to = ["https://www.w3.org/ns/activitystreams#Public"]

    mentioned_users = Enum.map(mentions, fn {_, %{ap_id: ap_id}} -> ap_id end)
    cc = [user.follower_address | mentioned_users]

    if inReplyTo do
      {to, Enum.uniq([inReplyTo.data["actor"] | cc])}
    else
      {to, cc}
    end
  end

  def to_for_user_and_mentions(user, mentions, inReplyTo, "unlisted") do
    {to, cc} = to_for_user_and_mentions(user, mentions, inReplyTo, "public")
    {cc, to}
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

  def make_content_html(status, mentions, attachments, tags, no_attachment_links \\ false) do
    status
    |> String.replace("\r", "")
    |> format_input(mentions, tags)
    |> maybe_add_attachments(attachments, no_attachment_links)
  end

  def make_context(%Activity{data: %{"context" => context}}), do: context
  def make_context(_), do: Utils.generate_context_id()

  def maybe_add_attachments(text, _attachments, _no_links = true), do: text

  def maybe_add_attachments(text, attachments, _no_links) do
    add_attachments(text, attachments)
  end

  def add_attachments(text, attachments) do
    attachment_text =
      Enum.map(attachments, fn
        %{"url" => [%{"href" => href} | _]} ->
          name = URI.decode(Path.basename(href))
          "<a href=\"#{href}\" class='attachment'>#{shortname(name)}</a>"

        _ ->
          ""
      end)

    Enum.join([text | attachment_text], "<br>")
  end

  def format_input(text, mentions, tags) do
    text
    |> Formatter.html_escape()
    |> String.replace("\n", "<br>")
    |> (&{[], &1}).()
    |> Formatter.add_links()
    |> Formatter.add_user_links(mentions)
    |> Formatter.add_hashtag_links(tags)
    |> Formatter.finalize()
  end

  def add_tag_links(text, tags) do
    tags =
      tags
      |> Enum.sort_by(fn {tag, _} -> -String.length(tag) end)

    Enum.reduce(tags, text, fn {full, tag}, text ->
      url = "#<a href='#{Pleroma.Web.base_url()}/tag/#{tag}' rel='tag'>#{tag}</a>"
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
      "tag" => tags |> Enum.map(fn {_, tag} -> tag end)
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

  def confirm_current_password(user, params) do
    case user do
      nil ->
        {:error, "Invalid credentials."}

      _ ->
        with %User{local: true} = db_user <- Repo.get(User, user.id),
             true <- Pbkdf2.checkpw(params["password"], db_user.password_hash) do
          {:ok, db_user}
        else
          _ -> {:error, "Invalid password."}
        end
    end
  end
end
