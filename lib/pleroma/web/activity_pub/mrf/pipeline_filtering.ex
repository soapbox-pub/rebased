# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.PipelineFiltering do
  @callback pipeline_filter(map(), keyword()) :: {:ok, map(), keyword()} | {:error, any()}
end
