# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.EmbedController do
  use Pleroma.Web, :controller

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User

  alias Pleroma.Web.ActivityPub.Visibility

  plug(:put_layout, :embed)

  def show(conn, %{"id" => id}) do
    with %Activity{local: true} = activity <-
           Activity.get_by_id_with_object(id),
         true <- Visibility.is_public?(activity.object) do
      {:ok, author} = User.get_or_fetch(activity.object.data["actor"])

      conn
      |> delete_resp_header("x-frame-options")
      |> delete_resp_header("content-security-policy")
      |> render("show.html",
        activity: activity,
        author: User.sanitize_html(author),
        counts: get_counts(activity)
      )
    end
  end

  defp get_counts(%Activity{} = activity) do
    %Object{data: data} = Object.normalize(activity, fetch: false)

    %{
      likes: Map.get(data, "like_count", 0),
      replies: Map.get(data, "repliesCount", 0),
      announces: Map.get(data, "announcement_count", 0)
    }
  end
end
