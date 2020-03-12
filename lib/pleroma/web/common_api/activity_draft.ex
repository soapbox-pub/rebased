# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI.ActivityDraft do
  alias Pleroma.Activity
  alias Pleroma.Conversation.Participation
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
            poll: nil,
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

  def create(user, params) do
    %__MODULE__{user: user}
    |> put_params(params)
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

  defp put_params(draft, params) do
    params = Map.put_new(params, "in_reply_to_status_id", params["in_reply_to_id"])
    %__MODULE__{draft | params: params}
  end

  defp status(%{params: %{"status" => status}} = draft) do
    %__MODULE__{draft | status: String.trim(status)}
  end

  defp summary(%{params: params} = draft) do
    %__MODULE__{draft | summary: Map.get(params, "spoiler_text", "")}
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

  defp in_reply_to(draft) do
    case Map.get(draft.params, "in_reply_to_status_id") do
      "" -> draft
      nil -> draft
      id -> %__MODULE__{draft | in_reply_to: Activity.get_by_id(id)}
    end
  end

  defp in_reply_to_conversation(draft) do
    in_reply_to_conversation = Participation.get(draft.params["in_reply_to_conversation_id"])
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
    case CommonAPI.check_expiry_date(draft.params["expires_in"]) do
      {:ok, expires_at} -> %__MODULE__{draft | expires_at: expires_at}
      {:error, message} -> add_error(draft, message)
    end
  end

  defp poll(draft) do
    case Utils.make_poll_data(draft.params) do
      {:ok, {poll, poll_emoji}} ->
        %__MODULE__{draft | poll: poll, emoji: Map.merge(draft.emoji, poll_emoji)}

      {:error, message} ->
        add_error(draft, message)
    end
  end

  defp content(draft) do
    {content_html, mentions, tags} =
      Utils.make_content_html(
        draft.status,
        draft.attachments,
        draft.params,
        draft.visibility
      )

    %__MODULE__{draft | content_html: content_html, mentions: mentions, tags: tags}
  end

  defp to_and_cc(draft) do
    addressed_users =
      draft.mentions
      |> Enum.map(fn {_, mentioned_user} -> mentioned_user.ap_id end)
      |> Utils.get_addressed_users(draft.params["to"])

    {to, cc} =
      Utils.get_to_and_cc(
        draft.user,
        addressed_users,
        draft.in_reply_to,
        draft.visibility,
        draft.in_reply_to_conversation
      )

    %__MODULE__{draft | to: to, cc: cc}
  end

  defp context(draft) do
    context = Utils.make_context(draft.in_reply_to, draft.in_reply_to_conversation)
    %__MODULE__{draft | context: context}
  end

  defp sensitive(draft) do
    sensitive = draft.params["sensitive"] || Enum.member?(draft.tags, {"#nsfw", "nsfw"})
    %__MODULE__{draft | sensitive: sensitive}
  end

  defp object(draft) do
    emoji = Map.merge(Pleroma.Emoji.Formatter.get_emoji_map(draft.full_payload), draft.emoji)

    object =
      Utils.make_note_data(
        draft.user.ap_id,
        draft.to,
        draft.context,
        draft.content_html,
        draft.attachments,
        draft.in_reply_to,
        draft.tags,
        draft.summary,
        draft.cc,
        draft.sensitive,
        draft.poll
      )
      |> Map.put("emoji", emoji)

    %__MODULE__{draft | object: object}
  end

  defp preview?(draft) do
    preview? = Pleroma.Web.ControllerHelper.truthy_param?(draft.params["preview"]) || false
    %__MODULE__{draft | preview?: preview?}
  end

  defp changes(draft) do
    direct? = draft.visibility == "direct"
    additional = %{"cc" => draft.cc, "directMessage" => direct?}

    additional =
      case draft.expires_at do
        %NaiveDateTime{} = expires_at -> Map.put(additional, "expires_at", expires_at)
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
