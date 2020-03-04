# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.OTPVersion do
  @spec version() :: String.t() | nil
  def version do
    # OTP Version https://erlang.org/doc/system_principles/versions.html#otp-version
    [
      Path.join(:code.root_dir(), "OTP_VERSION"),
      Path.join([:code.root_dir(), "releases", :erlang.system_info(:otp_release), "OTP_VERSION"])
    ]
    |> get_version_from_files()
  end

  @spec get_version_from_files([Path.t()]) :: String.t() | nil
  def get_version_from_files([]), do: nil

  def get_version_from_files([path | paths]) do
    if File.exists?(path) do
      path
      |> File.read!()
      |> String.replace(~r/\r|\n|\s/, "")
    else
      get_version_from_files(paths)
    end
  end
end
