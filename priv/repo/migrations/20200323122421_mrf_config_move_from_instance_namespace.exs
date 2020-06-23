defmodule Pleroma.Repo.Migrations.MrfConfigMoveFromInstanceNamespace do
  use Ecto.Migration

  alias Pleroma.ConfigDB

  @old_keys [:rewrite_policy, :mrf_transparency, :mrf_transparency_exclusions]
  def change do
    config = ConfigDB.get_by_params(%{group: ":pleroma", key: ":instance"})

    if config do
      old_instance = ConfigDB.from_binary(config.value)

      mrf =
        old_instance
        |> Keyword.take(@old_keys)
        |> Keyword.new(fn
          {:rewrite_policy, policies} -> {:policies, policies}
          {:mrf_transparency, transparency} -> {:transparency, transparency}
          {:mrf_transparency_exclusions, exclusions} -> {:transparency_exclusions, exclusions}
        end)

      if mrf != [] do
        {:ok, _} =
          ConfigDB.create(
            %{group: ":pleroma", key: ":mrf", value: ConfigDB.to_binary(mrf)},
            false
          )

        new_instance = Keyword.drop(old_instance, @old_keys)

        if new_instance != [] do
          {:ok, _} = ConfigDB.update(config, %{value: ConfigDB.to_binary(new_instance)}, false)
        else
          {:ok, _} = ConfigDB.delete(config)
        end
      end
    end
  end
end
