defmodule Pleroma.OTPVersion do
  @type check_status() :: :undefined | {:error, String.t()} | :ok

  require Logger

  @spec check_version() :: check_status()
  def check_version do
    # OTP Version https://erlang.org/doc/system_principles/versions.html#otp-version
    paths = [
      Path.join(:code.root_dir(), "OTP_VERSION"),
      Path.join([:code.root_dir(), "releases", :erlang.system_info(:otp_release), "OTP_VERSION"])
    ]

    :tesla
    |> Application.get_env(:adapter)
    |> get_and_check_version(paths)
  end

  @spec get_and_check_version(module(), [Path.t()]) :: check_status()
  def get_and_check_version(Tesla.Adapter.Gun, paths) do
    paths
    |> check_files()
    |> check_version()
  end

  def get_and_check_version(_, _), do: :ok

  defp check_files([]), do: nil

  defp check_files([path | paths]) do
    if File.exists?(path) do
      File.read!(path)
    else
      check_files(paths)
    end
  end

  defp check_version(nil), do: :undefined

  defp check_version(version) do
    try do
      version = String.replace(version, ~r/\r|\n|\s/, "")

      formatted =
        version
        |> String.split(".")
        |> Enum.map(&String.to_integer/1)
        |> Enum.take(2)

      with [major, minor] when length(formatted) == 2 <- formatted,
           true <- (major == 22 and minor >= 2) or major > 22 do
        :ok
      else
        false -> {:error, version}
        _ -> :undefined
      end
    rescue
      _ -> :undefined
    catch
      _ -> :undefined
    end
  end
end
