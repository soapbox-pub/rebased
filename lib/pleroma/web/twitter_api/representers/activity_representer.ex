# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

# FIXME: Remove this module?
# THIS MODULE IS DEPRECATED! DON'T USE IT!
# USE THE Pleroma.Web.TwitterAPI.Views.ActivityView MODULE!
defmodule Pleroma.Web.TwitterAPI.Representers.ActivityRepresenter do
  def to_map(activity, opts) do
    Pleroma.Web.TwitterAPI.ActivityView.render(
      "activity.json",
      Map.put(opts, :activity, activity)
    )
  end
end
