defmodule Pleroma.Web.OStatus do
  alias Pleroma.Web

  def feed_path(user) do
    "#{user.ap_id}/feed.atom"
  end

  def pubsub_path() do
    "#{Web.base_url}/push/hub"
  end

  def user_path(user) do
  end
end
