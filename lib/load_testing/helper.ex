defmodule Pleroma.LoadTesting.Helper do
  defmacro __using__(_) do
    quote do
      import Ecto.Query
      alias Pleroma.Repo
      alias Pleroma.User

      defp to_sec(microseconds), do: microseconds / 1_000_000
    end
  end
end
