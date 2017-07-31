defmodule Pleroma.Web.TwitterAPI.Utils do
  alias Pleroma.{Repo, Object, Formatter, User, Activity}
  alias Pleroma.Web.ActivityPub.Utils
  alias Calendar.Strftime

  def attachments_from_ids(ids) do
    Enum.map(ids || [], fn (media_id) ->
      Repo.get(Object, media_id).data
    end)
  end

  def add_attachments(text, attachments) do
    attachment_text = Enum.map(attachments, fn
      (%{"url" => [%{"href" => href} | _]}) ->
        "<a href=\"#{URI.encode(href)}\" class='attachment'>#{Path.basename(href)}</a>"
      _ -> ""
    end)
    Enum.join([text | attachment_text], "<br />\n")
  end

  def format_input(text, mentions) do
    HtmlSanitizeEx.strip_tags(text)
    |> Formatter.linkify
    |> String.replace("\n", "<br />\n")
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

  def wrap_in_p(text), do: "<p>#{text}</p>"

  def make_content_html(status, mentions, attachments) do
    status
    |> format_input(mentions)
    |> add_attachments(attachments)
    |> wrap_in_p
  end

  def make_context(%Activity{data: %{"context" => context}}), do: context
  def make_context(_), do: Utils.generate_context_id

  # TODO: Move this to a more fitting space
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
end
