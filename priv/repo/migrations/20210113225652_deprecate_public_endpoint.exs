# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.DeprecatePublicEndpoint do
  use Ecto.Migration

  def up do
    with %Pleroma.ConfigDB{} = s3_config <-
           Pleroma.ConfigDB.get_by_params(%{group: :pleroma, key: Pleroma.Uploaders.S3}),
         %Pleroma.ConfigDB{} = upload_config <-
           Pleroma.ConfigDB.get_by_params(%{group: :pleroma, key: Pleroma.Upload}) do
      public_endpoint = s3_config.value[:public_endpoint]

      if !is_nil(public_endpoint) do
        upload_value = upload_config.value |> Keyword.merge(base_url: public_endpoint)

        upload_config
        |> Ecto.Changeset.change(value: upload_value)
        |> Pleroma.Repo.update()

        s3_value = s3_config.value |> Keyword.delete(:public_endpoint)

        s3_config
        |> Ecto.Changeset.change(value: s3_value)
        |> Pleroma.Repo.update()
      end
    else
      _ -> :ok
    end
  end

  def down do
    with %Pleroma.ConfigDB{} = upload_config <-
           Pleroma.ConfigDB.get_by_params(%{group: :pleroma, key: Pleroma.Upload}),
         %Pleroma.ConfigDB{} = s3_config <-
           Pleroma.ConfigDB.get_by_params(%{group: :pleroma, key: Pleroma.Uploaders.S3}) do
      base_url = upload_config.value[:base_url]

      if !is_nil(base_url) do
        s3_value = s3_config.value |> Keyword.merge(public_endpoint: base_url)

        s3_config
        |> Ecto.Changeset.change(value: s3_value)
        |> Pleroma.Repo.update()

        upload_value = upload_config.value |> Keyword.delete(:base_url)

        upload_config
        |> Ecto.Changeset.change(value: upload_value)
        |> Pleroma.Repo.update()
      end
    else
      _ -> :ok
    end
  end
end
