# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI.ActivityDraft do
  alias Pleroma.Activity
  alias Pleroma.Conversation.Participation
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils

  import Pleroma.Web.Gettext

  defstruct valid?: true,
            errors: [],
            user: nil,
            params: %{},
            status: nil,
            summary: nil,
            full_payload: nil,
            attachments: [],
            in_reply_to: nil,
            in_reply_to_conversation: nil,
            visibility: nil,
            expires_at: nil,
            extra: nil,
            emoji: %{},
            content_html: nil,
            mentions: [],
            tags: [],
            to: [],
            cc: [],
            context: nil,
            sensitive: false,
            object: nil,
            preview?: false,
            changes: %{}

  def new(user, params) do
    %__MODULE__{user: user}
    |> put_params(params)
  end

  def create(user, params) do
    user
    |> new(params)
    |> status()
    |> summary()
    |> with_valid(&attachments/1)
    |> full_payload()
    |> expires_at()
    |> poll()
    |> with_valid(&in_reply_to/1)
    |> with_valid(&in_reply_to_conversation/1)
    |> with_valid(&visibility/1)
    |> content()
    |> with_valid(&to_and_cc/1)
    |> with_valid(&context/1)
    |> sensitive()
    |> with_valid(&object/1)
    |> preview?()
    |> with_valid(&changes/1)
    |> validate()
  end

  def listen(user, params) do
    user
    |> new(params)
    |> visibility()
    |> to_and_cc()
    |> context()
    |> listen_object()
    |> with_valid(&changes/1)
    |> validate()
  end

  defp listen_object(draft) do
    object =
      draft.params
      |> Map.take([:album, :artist, :title, :length])
      |> Map.new(fn {key, value} -> {to_string(key), value} end)
      |> Map.put("type", "Audio")
      |> Map.put("to", draft.to)
      |> Map.put("cc", draft.cc)
      |> Map.put("actor", draft.user.ap_id)

    %__MODULE__{draft | object: object}
  end

  defp put_params(draft, params) do
    params = Map.put_new(params, :in_reply_to_status_id, params[:in_reply_to_id])
    %__MODULE__{draft | params: params}
  end

  defp status(%{params: %{status: status}} = draft) do
    %__MODULE__{draft | status: String.trim(status)}
  end

  defp summary(%{params: params} = draft) do
    %__MODULE__{draft | summary: Map.get(params, :spoiler_text, "")}
  end

  defp full_payload(%{status: status, summary: summary} = draft) do
    full_payload = String.trim(status <> summary)

    case Utils.validate_character_limit(full_payload, draft.attachments) do
      :ok -> %__MODULE__{draft | full_payload: full_payload}
      {:error, message} -> add_error(draft, message)
    end
  end

  defp attachments(%{params: params} = draft) do
    attachments = Utils.attachments_from_ids(params)
    %__MODULE__{draft | attachments: attachments}
  end

  defp in_reply_to(%{params: %{in_reply_to_status_id: ""}} = draft), do: draft

  defp in_reply_to(%{params: %{in_reply_to_status_id: id}} = draft) when is_binary(id) do
    %__MODULE__{draft | in_reply_to: Activity.get_by_id(id)}
  end

  defp in_reply_to(%{params: %{in_reply_to_status_id: %Activity{} = in_reply_to}} = draft) do
    %__MODULE__{draft | in_reply_to: in_reply_to}
  end

  defp in_reply_to(draft), do: draft

  defp in_reply_to_conversation(draft) do
    in_reply_to_conversation = Participation.get(draft.params[:in_reply_to_conversation_id])
    %__MODULE__{draft | in_reply_to_conversation: in_reply_to_conversation}
  end

  defp visibility(%{params: params} = draft) do
    case CommonAPI.get_visibility(params, draft.in_reply_to, draft.in_reply_to_conversation) do
      {visibility, "direct"} when visibility != "direct" ->
        add_error(draft, dgettext("errors", "The message visibility must be direct"))

      {visibility, _} ->
        %__MODULE__{draft | visibility: visibility}
    end
  end

  defp expires_at(draft) do
    case CommonAPI.check_expiry_date(draft.params[:expires_in]) do
      {:ok, expires_at} -> %__MODULE__{draft | expires_at: expires_at}
      {:error, message} -> add_error(draft, message)
    end
  end

  defp poll(draft) do
    case Utils.make_poll_data(draft.params) do
      {:ok, {poll, poll_emoji}} ->
        %__MODULE__{draft | extra: poll, emoji: Map.merge(draft.emoji, poll_emoji)}

      {:error, message} ->
        add_error(draft, message)
    end
  end

  defp content(draft) do
    {content_html, mentioned_users, tags} = Utils.make_content_html(draft)

    mentions =
      mentioned_users
      |> Enum.map(fn {_, mentioned_user} -> mentioned_user.ap_id end)
      |> Utils.get_addressed_users(draft.params[:to])

    %__MODULE__{draft | content_html: content_html, mentions: mentions, tags: tags}
  end

  defp to_and_cc(draft) do
    {to, cc} = Utils.get_to_and_cc(draft)
    %__MODULE__{draft | to: to, cc: cc}
  end

  defp context(draft) do
    context = Utils.make_context(draft.in_reply_to, draft.in_reply_to_conversation)
    %__MODULE__{draft | context: context}
  end

  defp sensitive(draft) do
    sensitive = draft.params[:sensitive]
    %__MODULE__{draft | sensitive: sensitive}
  end

  defp object(draft) do
    emoji = Map.merge(Pleroma.Emoji.Formatter.get_emoji_map(draft.full_payload), draft.emoji)

    # Sometimes people create posts with subject containing emoji,
    # since subjects are usually copied this will result in a broken
    # subject when someone replies from an instance that does not have
    # the emoji or has it under different shortcode. This is an attempt
    # to mitigate this by copying emoji from inReplyTo if they are present
    # in the subject.
    summary_emoji =
      with %Activity{} <- draft.in_reply_to,
           %Object{data: %{"tag" => [_ | _] = tag}} <- Object.normalize(draft.in_reply_to) do
        Enum.reduce(tag, %{}, fn
          %{"type" => "Emoji", "name" => name, "icon" => %{"url" => url}}, acc ->
            if String.contains?(draft.summary, name) do
              Map.put(acc, name, url)
            else
              acc
            end

          _, acc ->
            acc
        end)
      else
        _ -> %{}
      end

    emoji = Map.merge(emoji, summary_emoji)

    {:ok, note_data, _meta} = Builder.note(draft)

    object =
      note_data
      |> Map.put("emoji", emoji)
      |> Map.put("source", draft.status)
      |> Map.put("generator", draft.params[:generator])

    %__MODULE__{draft | object: object}
  end

  defp preview?(draft) do
    preview? = Pleroma.Web.Utils.Params.truthy_param?(draft.params[:preview])
    %__MODULE__{draft | preview?: preview?}
  end

  defp changes(draft) do
    direct? = draft.visibility == "direct"
    additional = %{"cc" => draft.cc, "directMessage" => direct?}

    additional =
      case draft.expires_at do
        %DateTime{} = expires_at -> Map.put(additional, "expires_at", expires_at)
        _ -> additional
      end

    changes =
      %{
        to: draft.to,
        actor: draft.user,
        context: draft.context,
        object: draft.object,
        additional: additional
      }
      |> Utils.maybe_add_list_data(draft.user, draft.visibility)

    %__MODULE__{draft | changes: changes}
  end

  defp with_valid(%{valid?: true} = draft, func), do: func.(draft)
  defp with_valid(draft, _func), do: draft

  defp add_error(draft, message) do
    %__MODULE__{draft | valid?: false, errors: [message | draft.errors]}
  end

  defp validate(%{valid?: true} = draft), do: {:ok, draft}
  defp validate(%{errors: [message | _]}), do: {:error, message}
end
