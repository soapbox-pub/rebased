defmodule Pleroma.Web.ActivityPub.Transmogrifier do
  @moduledoc """
  A module to handle coding from internal to wire ActivityPub and back.
  """
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub

  @doc """
  Modifies an incoming AP object (mastodon format) to our internal format.
  """
  def fix_object(object) do
    object
    |> Map.put("actor", object["attributedTo"])
  end

  # TODO: validate those with a Ecto scheme
  # - tags
  # - emoji
  def handle_incoming(%{"type" => "Create", "object" => %{"type" => "Note"} = object} = data) do
    with %User{} = user <- User.get_or_fetch_by_ap_id(data["actor"]) do
      object = fix_object(data["object"])
      params = %{
        to: data["to"],
        object: object,
        actor: user,
        context: data["object"]["conversation"],
        local: false,
        published: data["published"],
        additional: Map.take(data, [
              "cc",
              "id"
            ])
      }

      ActivityPub.create(params)
    else
      _e -> :error
    end
  end

  def prepare_incoming(_) do
    :error
  end
end
