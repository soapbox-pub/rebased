defmodule Pleroma.Web.ActivityPub.ObjectValidators.Types.Recipients do
  use Ecto.Type

  def type, do: {:array, :string}

  def cast(object) when is_binary(object) do
    cast([object])
  end

  def cast([_ | _] = data), do: {:ok, data}

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
