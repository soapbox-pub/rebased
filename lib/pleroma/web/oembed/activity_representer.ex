defmodule Pleroma.Web.OEmbed.ActivityRepresenter do
  alias Pleroma.{Activity, User, Object}
  alias Pleroma.Web.OStatus.UserRepresenter

  def to_simple_form(%{data: %{"object" => %{"type" => "Note"}}} = activity, user, with_author) do
    h = fn str -> [to_charlist(str)] end

    content =  if activity.data["object"]["content"] do
      [{:content, [], h.(activity.data["object"]["content"])}]
    else
      []
    end

    [
      {:version, ["1.0"]},
      {:type, ["link"]},
    ] ++ content

  end

  def wrap_with_entry(simple_form) do
    [ { :oembed, [], simple_form } ]
  end

end
