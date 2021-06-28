# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.PrivacyScope do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "PrivacyScope",
    description:
      "Privacy requirement for statuses to the group. Changing this only affects future statuses.",
    type: :string,
    enum: ["public", "members_only"]
  })
end
