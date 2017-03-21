defmodule Pleroma.Web.ActivityPub.ActivityPub do
  alias Pleroma.Repo
  alias Pleroma.Activity

  def insert(map) when is_map(map) do
    Repo.insert(%Activity{data: map})
  end
end
