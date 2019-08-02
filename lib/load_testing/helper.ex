defmodule Pleroma.LoadTesting.Helper do
  defmacro __using__(_) do
    quote do
      import Ecto.Query
      alias Pleroma.Activity
      alias Pleroma.Notification
      alias Pleroma.Object
      alias Pleroma.Repo
      alias Pleroma.User
      alias Pleroma.Web.ActivityPub
      alias Pleroma.Web.CommonAPI

      defp to_sec(microseconds), do: microseconds / 1_000_000
    end
  end
end
