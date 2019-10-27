# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StaticFE.ActivityRepresenter do
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.Router.Helpers

  def prepare_activity(%User{} = user, %Object{} = object, activity_id) do
    %{}
    |> set_user(user)
    |> set_object(object)
    |> set_title(object)
    |> set_content(object)
    |> set_link(activity_id)
    |> set_published(object)
    |> set_attachments(object)
  end

  def prepare_activity(%User{} = user, %Activity{} = activity),
    do: prepare_activity(user, Object.normalize(activity.data["object"]), activity.id)

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

  defp set_link(data, activity_id),
    do: Map.put(data, :link, Helpers.o_status_url(Pleroma.Web.Endpoint, :notice, activity_id))

  defp set_published(data, %Object{data: %{"published" => published}}),
    do: Map.put(data, :published, published)

  # TODO: attachments
  defp set_attachments(data, _), do: Map.put(data, :attachments, [])

  def represent(activity_id) do
    with %Activity{data: %{"type" => "Create"}} = activity <- Activity.get_by_id(activity_id),
         true <- Visibility.is_public?(activity),
         %Object{} = object <- Object.normalize(activity.data["object"]),
         %User{} = user <- User.get_or_fetch(activity.data["actor"]),
         data <- prepare_activity(user, object, activity_id) do
      {:ok, data}
    else
      e ->
        {:error, e}
    end
  end
end
