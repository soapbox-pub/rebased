# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.DeprecatePublicEndpointTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  import Pleroma.Tests.Helpers
  alias Pleroma.ConfigDB

  setup do: clear_config(Pleroma.Upload)
  setup do: clear_config(Pleroma.Uploaders.S3)
  setup_all do: require_migration("20210113225652_deprecate_public_endpoint")

  test "up/0 migrates public_endpoint to base_url", %{migration: migration} do
    s3_values = [
      public_endpoint: "https://coolhost.com/",
      bucket: "secret_bucket"
    ]

    insert(:config, group: :pleroma, key: Pleroma.Uploaders.S3, value: s3_values)

    upload_values = [
      uploader: Pleroma.Uploaders.S3
    ]

    insert(:config, group: :pleroma, key: Pleroma.Upload, value: upload_values)

    migration.up()

    assert [bucket: "secret_bucket"] ==
             ConfigDB.get_by_params(%{group: :pleroma, key: Pleroma.Uploaders.S3}).value

    assert [uploader: Pleroma.Uploaders.S3, base_url: "https://coolhost.com/"] ==
             ConfigDB.get_by_params(%{group: :pleroma, key: Pleroma.Upload}).value
  end

  test "down/0 reverts base_url to public_endpoint", %{migration: migration} do
    s3_values = [
      bucket: "secret_bucket"
    ]

    insert(:config, group: :pleroma, key: Pleroma.Uploaders.S3, value: s3_values)

    upload_values = [
      uploader: Pleroma.Uploaders.S3,
      base_url: "https://coolhost.com/"
    ]

    insert(:config, group: :pleroma, key: Pleroma.Upload, value: upload_values)

    migration.down()

    assert [bucket: "secret_bucket", public_endpoint: "https://coolhost.com/"] ==
             ConfigDB.get_by_params(%{group: :pleroma, key: Pleroma.Uploaders.S3}).value

    assert [uploader: Pleroma.Uploaders.S3] ==
             ConfigDB.get_by_params(%{group: :pleroma, key: Pleroma.Upload}).value
  end
end
