defmodule Pleroma.Repo.Migrations.QuarantainedStringToTuple do
  use Ecto.Migration

  alias Pleroma.ConfigDB

  def up,
    do:
      ConfigDB.get_by_params(%{group: :pleroma, key: :instance})
      |> update_quarantined_instances_to_tuples

  def down,
    do:
      ConfigDB.get_by_params(%{group: :pleroma, key: :instance})
      |> update_quarantined_instances_to_strings

  defp update_quarantined_instances_to_tuples(%{value: settings}) do
    settings |> List.keyfind(:quarantined_instances, 0) |> update_to_tuples
  end

  defp update_quarantined_instances_to_tuples(nil), do: {:ok, nil}

  defp update_to_tuples({:quarantined_instances, instance_list}) do
    new_value =
      instance_list
      |> Enum.map(fn
        {v, r} -> {v, r}
        v -> {v, ""}
      end)

    ConfigDB.update_or_create(%{
      group: :pleroma,
      key: :instance,
      value: [quarantined_instances: new_value]
    })
  end

  defp update_to_tuples(nil), do: {:ok, nil}

  defp update_quarantined_instances_to_strings(%{value: settings}) do
    settings |> List.keyfind(:quarantined_instances, 0) |> update_to_strings
  end

  defp update_quarantined_instances_to_strings(nil), do: {:ok, nil}

  defp update_to_strings({:quarantined_instances, instance_list}) do
    new_value =
      instance_list
      |> Enum.map(fn
        {v, _} -> v
        v -> v
      end)

    ConfigDB.update_or_create(%{
      group: :pleroma,
      key: :instance,
      value: [quarantined_instances: new_value]
    })
  end

  defp update_to_strings(nil), do: {:ok, nil}
end
