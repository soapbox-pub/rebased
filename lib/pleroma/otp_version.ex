# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.OTPVersion do
  @type check_status() :: :ok | :undefined | {:error, String.t()}

  @spec check!() :: :ok | no_return()
  def check! do
    case check() do
      :ok ->
        :ok

      {:error, version} ->
        raise "
            !!!OTP VERSION WARNING!!!
            You are using gun adapter with OTP version #{version}, which doesn't support correct handling of unordered certificates chains.
            "

      :undefined ->
        raise "
            !!!OTP VERSION WARNING!!!
            To support correct handling of unordered certificates chains - OTP version must be > 22.2.
            "
    end
  end

  @spec check() :: check_status()
  def check do
    # OTP Version https://erlang.org/doc/system_principles/versions.html#otp-version
    [
      Path.join(:code.root_dir(), "OTP_VERSION"),
      Path.join([:code.root_dir(), "releases", :erlang.system_info(:otp_release), "OTP_VERSION"])
    ]
    |> get_version_from_files()
    |> do_check()
  end

  @spec check([Path.t()]) :: check_status()
  def check(paths) do
    paths
    |> get_version_from_files()
    |> do_check()
  end

  defp get_version_from_files([]), do: nil

  defp get_version_from_files([path | paths]) do
    if File.exists?(path) do
      File.read!(path)
    else
      get_version_from_files(paths)
    end
  end

  defp do_check(nil), do: :undefined

  defp do_check(version) do
    version = String.replace(version, ~r/\r|\n|\s/, "")

    [major, minor] =
      version
      |> String.split(".")
      |> Enum.map(&String.to_integer/1)
      |> Enum.take(2)

    if (major == 22 and minor >= 2) or major > 22 do
      :ok
    else
      {:error, version}
    end
  end
end
