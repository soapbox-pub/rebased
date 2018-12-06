defmodule Pleroma.Web.ActivityPub.MRF.EnsureRePrepended do
  alias Pleroma.Object

  @behaviour Pleroma.Web.ActivityPub.MRF

  def filter_by_summary(
        %{"summary" => parent_summary} = parent,
        %{"summary" => child_summary} = child
      )
      when not is_nil(child_summary) and child_summary == parent_summary and
             byte_size(child_summary) > 1 do
    if not String.starts_with?(child_summary, "re:") do
      Map.put(child, "summary", "re: " <> child_summary)
    else
      child
    end
  end

  def filter_by_summary(parent, child), do: child

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
