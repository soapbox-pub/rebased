defmodule Pleroma.Repo.Migrations.MoveWelcomeSettings do
  use Ecto.Migration

  alias Pleroma.ConfigDB

  @old_keys [:welcome_user_nickname, :welcome_message]

  def up do
    with {:ok, config, {keep_values, move_values}} <- get_old_values() do
      insert_welcome_settings(move_values)
      update_instance_config(config, keep_values)
    end
  end

  def down do
    with {:ok, welcome_config, revert_values} <- get_revert_values() do
      revert_instance_config(revert_values)
      Pleroma.Repo.delete(welcome_config)
    end
  end

  defp insert_welcome_settings([_ | _] = values) do
    unless String.trim(values[:welcome_message]) == "" do
      config_values = [
        direct_message: %{
          enabled: true,
          sender_nickname: values[:welcome_user_nickname],
          message: values[:welcome_message]
        },
        email: %{
          enabled: false,
          sender: nil,
          subject: "Welcome to <%= instance_name %>",
          html: "Welcome to <%= instance_name %>",
          text: "Welcome to <%= instance_name %>"
        }
      ]

      {:ok, _} =
        %ConfigDB{}
        |> ConfigDB.changeset(%{group: :pleroma, key: :welcome, value: config_values})
        |> Pleroma.Repo.insert()
    end

    :ok
  end

  defp insert_welcome_settings(_), do: :noop

  defp revert_instance_config(%{} = revert_values) do
    values = [
      welcome_user_nickname: revert_values[:sender_nickname],
      welcome_message: revert_values[:message]
    ]

    ConfigDB.update_or_create(%{group: :pleroma, key: :instance, value: values})
  end

  defp revert_instance_config(_), do: :noop

  defp update_instance_config(config, values) do
    {:ok, _} =
      config
      |> ConfigDB.changeset(%{value: values})
      |> Pleroma.Repo.update()

    :ok
  end

  defp get_revert_values do
    config = ConfigDB.get_by_params(%{group: :pleroma, key: :welcome})

    cond do
      is_nil(config) -> {:noop, nil, nil}
      true -> {:ok, config, config.value[:direct_message]}
    end
  end

  defp get_old_values do
    config = ConfigDB.get_by_params(%{group: :pleroma, key: :instance})

    cond do
      is_nil(config) ->
        {:noop, config, {}}

      is_binary(config.value[:welcome_message]) ->
        {:ok, config,
         {Keyword.drop(config.value, @old_keys), Keyword.take(config.value, @old_keys)}}

      true ->
        {:ok, config, {Keyword.drop(config.value, @old_keys), []}}
    end
  end
end
