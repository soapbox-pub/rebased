defmodule Pleroma.Web.TwitterAPI.Utils do
  alias Pleroma.{Repo, Object, Formatter, User, Activity}
  alias Pleroma.Web.ActivityPub.Utils

  def attachments_from_ids(ids) do
    Enum.map(ids || [], fn (media_id) ->
      Repo.get(Object, media_id).data
    end)
  end

  def add_attachments(text, attachments) do
    attachment_text = Enum.map(attachments, fn
      (%{"url" => [%{"href" => href} | _]}) ->
        "<a href='#{href}' class='attachment'>#{Path.basename(href)}</a>"
      _ -> ""
    end)
    Enum.join([text | attachment_text], "<br>")
  end

  def format_input(text, mentions) do
    HtmlSanitizeEx.strip_tags(text)
    |> Formatter.linkify
    |> String.replace("\n", "<br>")
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
      String.replace(text, uuid, "<a href='#{ap_id}'>#{match}</a>")
    end)
  end

  def make_content_html(status, mentions, attachments) do
    status
    |> format_input(mentions)
    |> add_attachments(attachments)
  end

  def make_context(%Activity{data: %{"context" => context}}), do: context
  def make_context(_), do: Utils.generate_context_id

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
end
