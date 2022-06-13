# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations do
  import Ecto.Changeset

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User

  @spec validate_any_presence(Ecto.Changeset.t(), [atom()]) :: Ecto.Changeset.t()
  def validate_any_presence(cng, fields) do
    non_empty =
      fields
      |> Enum.map(fn field -> get_field(cng, field) end)
      |> Enum.any?(fn
        nil -> false
        [] -> false
        _ -> true
      end)

    if non_empty do
      cng
    else
      fields
      |> Enum.reduce(cng, fn field, cng ->
        cng
        |> add_error(field, "none of #{inspect(fields)} present")
      end)
    end
  end

  @spec validate_actor_presence(Ecto.Changeset.t(), keyword()) :: Ecto.Changeset.t()
  def validate_actor_presence(cng, options \\ []) do
    field_name = Keyword.get(options, :field_name, :actor)

    cng
    |> validate_change(field_name, fn field_name, actor ->
      case User.get_cached_by_ap_id(actor) do
        %User{is_active: false} ->
          [{field_name, "user is deactivated"}]

        %User{} ->
          []

        _ ->
          [{field_name, "can't find user"}]
      end
    end)
  end

  @spec validate_object_presence(Ecto.Changeset.t(), keyword()) :: Ecto.Changeset.t()
  def validate_object_presence(cng, options \\ []) do
    field_name = Keyword.get(options, :field_name, :object)
    allowed_types = Keyword.get(options, :allowed_types, false)

    cng
    |> validate_change(field_name, fn field_name, object_id ->
      object = Object.get_cached_by_ap_id(object_id) || Activity.get_by_ap_id(object_id)

      cond do
        !object ->
          [{field_name, "can't find object"}]

        object && allowed_types && object.data["type"] not in allowed_types ->
          [{field_name, "object not in allowed types"}]

        true ->
          []
      end
    end)
  end

  @spec validate_object_or_user_presence(Ecto.Changeset.t(), keyword()) :: Ecto.Changeset.t()
  def validate_object_or_user_presence(cng, options \\ []) do
    field_name = Keyword.get(options, :field_name, :object)
    options = Keyword.put(options, :field_name, field_name)

    actor_cng =
      cng
      |> validate_actor_presence(options)

    object_cng =
      cng
      |> validate_object_presence(options)

    if actor_cng.valid?, do: actor_cng, else: object_cng
  end

  @spec validate_host_match(Ecto.Changeset.t(), [atom()]) :: Ecto.Changeset.t()
  def validate_host_match(cng, fields \\ [:id, :actor]) do
    if same_domain?(cng, fields) do
      cng
    else
      fields
      |> Enum.reduce(cng, fn field, cng ->
        cng
        |> add_error(field, "hosts of #{inspect(fields)} aren't matching")
      end)
    end
  end

  @spec validate_fields_match(Ecto.Changeset.t(), [atom()]) :: Ecto.Changeset.t()
  def validate_fields_match(cng, fields) do
    if map_unique?(cng, fields) do
      cng
    else
      fields
      |> Enum.reduce(cng, fn field, cng ->
        cng
        |> add_error(field, "Fields #{inspect(fields)} aren't matching")
      end)
    end
  end

  defp map_unique?(cng, fields, func \\ & &1) do
    Enum.reduce_while(fields, nil, fn field, acc ->
      value =
        cng
        |> get_field(field)
        |> func.()

      case {value, acc} do
        {value, nil} -> {:cont, value}
        {value, value} -> {:cont, value}
        _ -> {:halt, false}
      end
    end)
  end

  @spec same_domain?(Ecto.Changeset.t(), [atom()]) :: boolean()
  def same_domain?(cng, fields \\ [:actor, :object]) do
    map_unique?(cng, fields, fn value -> URI.parse(value).host end)
  end

  # This figures out if a user is able to create, delete or modify something
  # based on the domain and superuser status
  @spec validate_modification_rights(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def validate_modification_rights(cng, privilege) do
    actor = User.get_cached_by_ap_id(get_field(cng, :actor))

    if User.privileged?(actor, privilege) || same_domain?(cng) do
      cng
    else
      cng
      |> add_error(:actor, "is not allowed to modify object")
    end
  end
end
