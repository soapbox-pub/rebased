defmodule Pleroma.Web.GraphQL.Schema do
  use Absinthe.Schema

  object :hello do
    field(:text, :string)
  end

  query do
    field :hello, :hello do
      resolve(fn _, _, _ -> {:ok, %{text: "world"}} end)
    end
  end
end
