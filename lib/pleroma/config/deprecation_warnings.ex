# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.DeprecationWarnings do
  require Logger

  def check_hellthread_threshold do
    if Pleroma.Config.get([:mrf_hellthread, :threshold]) do
      Logger.warn("""
      !!!DEPRECATION WARNING!!!
      You are using the old configuration mechanism for the hellthread filter. Please check config.md.
      """)
    end
  end

  def warn do
    check_hellthread_threshold()
  end
end
