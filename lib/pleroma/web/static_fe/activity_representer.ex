# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StaticFE.ActivityRepresenter do
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.Router.Helpers

  def prepare_activity(%User{} = user, %Activity{} = activity) do
    object = Object.normalize(activity.data["object"])

    %{}
    |> set_user(user)
    |> set_object(object)
    |> set_title(object)
    |> set_content(object)
    |> set_link(activity.id)
    |> set_published(object)
    |> set_sensitive(object)
    |> set_attachment(object.data["attachment"])
    |> set_attachments(object)
  end

  defp set_user(data, %User{} = user), do: Map.put(data, :user, user)

  defp set_object(data, %Object{} = object), do: Map.put(data, :object, object)

  defp set_title(data, %Object{data: %{"name" => name}}) when is_binary(name),
    do: Map.put(data, :title, name)

  defp set_title(data, %Object{data: %{"summary" => summary}}) when is_binary(summary),
    do: Map.put(data, :title, summary)

  defp set_title(data, _), do: Map.put(data, :title, nil)

  defp set_content(data, %Object{data: %{"content" => content}}) when is_binary(content),
    do: Map.put(data, :content, content)

  defp set_content(data, _), do: Map.put(data, :content, nil)

  defp set_attachment(data, attachment), do: Map.put(data, :attachment, attachment)

  defp set_link(data, activity_id),
    do: Map.put(data, :link, Helpers.o_status_url(Pleroma.Web.Endpoint, :notice, activity_id))

  defp set_published(data, %Object{data: %{"published" => published}}),
    do: Map.put(data, :published, published)

  defp set_sensitive(data, %Object{data: %{"sensitive" => sensitive}}),
    do: Map.put(data, :sensitive, sensitive)

  # TODO: attachments
  defp set_attachments(data, _), do: Map.put(data, :attachments, [])

  def represent(activity_id) do
    with %Activity{data: %{"type" => "Create"}} = activity <-
           Activity.get_by_id_with_object(activity_id),
         true <- Visibility.is_public?(activity),
         {:ok, %User{} = user} <- User.get_or_fetch(activity.data["actor"]) do
      {:ok, prepare_activity(user, activity)}
    else
      e ->
        {:error, e}
    end
  end
end
