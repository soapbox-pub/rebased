defmodule Pleroma.Web.ActivityPub.ObjectValidators.Types.ObjectID do
  use Ecto.Type

  def type, do: :string

  def cast(object) when is_binary(object) do
    {:ok, object}
  end

  def cast(%{"id" => object}) when is_binary(object) do
    {:ok, object}
  end

  def cast(_) do
    :error
  end

  def dump(data) do
    {:ok, data}
  end

  def load(data) do
    {:ok, data}
  end
end
