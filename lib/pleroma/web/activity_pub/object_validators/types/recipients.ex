defmodule Pleroma.Web.ActivityPub.ObjectValidators.Types.Recipients do
  use Ecto.Type

  alias Pleroma.Web.ActivityPub.ObjectValidators.Types.ObjectID

  def type, do: {:array, ObjectID}

  def cast(object) when is_binary(object) do
    cast([object])
  end

  def cast(data) when is_list(data) do
    data
    |> Enum.reduce({:ok, []}, fn element, acc ->
      case {acc, ObjectID.cast(element)} do
        {:error, _} -> :error
        {_, :error} -> :error
        {{:ok, list}, {:ok, id}} -> {:ok, [id | list]}
      end
    end)
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
