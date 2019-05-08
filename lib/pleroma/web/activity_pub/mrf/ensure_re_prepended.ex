# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.EnsureRePrepended do
  alias Pleroma.Object

  @moduledoc "Ensure a re: is prepended on replies to a post with a Subject"
  @behaviour Pleroma.Web.ActivityPub.MRF

  @reply_prefix Regex.compile!("^re:[[:space:]]*", [:caseless])
  def filter_by_summary(
        %{"summary" => parent_summary} = _parent,
        %{"summary" => child_summary} = child
      )
      when not is_nil(child_summary) and byte_size(child_summary) > 0 and
             not is_nil(parent_summary) and byte_size(parent_summary) > 0 do
    if (child_summary == parent_summary and not Regex.match?(@reply_prefix, child_summary)) or
         (Regex.match?(@reply_prefix, parent_summary) &&
            Regex.replace(@reply_prefix, parent_summary, "") == child_summary) do
      Map.put(child, "summary", "re: " <> child_summary)
    else
      child
    end
  end

  def filter_by_summary(_parent, child), do: child

  def filter(%{"type" => activity_type} = object) when activity_type == "Create" do
    child = object["object"]
    in_reply_to = Object.normalize(child["inReplyTo"])

    child =
      if(in_reply_to,
        do: filter_by_summary(in_reply_to.data, child),
        else: child
      )

    object = Map.put(object, "object", child)

    {:ok, object}
  end

  def filter(object), do: {:ok, object}
end
