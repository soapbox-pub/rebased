# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Exec do
  @moduledoc "Pleroma wrapper around Exexec commands."

  alias Pleroma.Config

  def ensure_started(options_overrides \\ %{}) do
    options =
      if Config.get([:exexec, :root_mode]) || System.get_env("USER") == "root" do
        # Note: running as `root` is discouraged (yet Gitlab CI does that by default)
        %{root: true, user: "root", limit_users: ["root"]}
      else
        %{}
      end

    options =
      options
      |> Map.merge(Config.get([:exexec, :options], %{}))
      |> Map.merge(options_overrides)

    with {:error, {:already_started, pid}} <- Exexec.start(options) do
      {:ok, pid}
    end
  end

  def run(cmd, options \\ %{}) do
    ensure_started()
    Exexec.run(cmd, options)
  end

  def cmd(cmd, options \\ %{}) do
    options = Map.merge(%{sync: true, stdout: true}, options)
    run(cmd, options)
  end
end
