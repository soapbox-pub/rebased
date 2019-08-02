# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.FlakeId do
  @moduledoc """
  Flake is a decentralized, k-ordered id generation service.

  Adapted from:

  * [flaky](https://github.com/nirvana/flaky), released under the terms of the Truly Free License,
  * [Flake](https://github.com/boundary/flake), Copyright 2012, Boundary, Apache License, Version 2.0
  """

  @type t :: binary

  @behaviour Ecto.Type
  use GenServer
  require Logger
  alias __MODULE__
  import Kernel, except: [to_string: 1]

  defstruct node: nil, time: 0, sq: 0

  @doc "Converts a binary Flake to a String"
  def to_string(<<0::integer-size(64), id::integer-size(64)>>) do
    Kernel.to_string(id)
  end

  def to_string(<<_::integer-size(64), _::integer-size(48), _::integer-size(16)>> = flake) do
    encode_base62(flake)
  end

  def to_string(s), do: s

  def from_string(int) when is_integer(int) do
    from_string(Kernel.to_string(int))
  end

  for i <- [-1, 0] do
    def from_string(unquote(i)), do: <<0::integer-size(128)>>
    def from_string(unquote(Kernel.to_string(i))), do: <<0::integer-size(128)>>
  end

  def from_string(<<_::integer-size(128)>> = flake), do: flake

  def from_string(string) when is_binary(string) and byte_size(string) < 18 do
    case Integer.parse(string) do
      {id, ""} -> <<0::integer-size(64), id::integer-size(64)>>
      _ -> nil
    end
  end

  def from_string(string) do
    string |> decode_base62 |> from_integer
  end

  def to_integer(<<integer::integer-size(128)>>), do: integer

  def from_integer(integer) do
    <<_time::integer-size(64), _node::integer-size(48), _seq::integer-size(16)>> =
      <<integer::integer-size(128)>>
  end

  @doc "Generates a Flake"
  @spec get :: binary
  def get, do: to_string(:gen_server.call(:flake, :get))

  # checks that ID is is valid FlakeID
  #
  @spec is_flake_id?(String.t()) :: boolean
  def is_flake_id?(id), do: is_flake_id?(String.to_charlist(id), true)
  defp is_flake_id?([c | cs], true) when c >= ?0 and c <= ?9, do: is_flake_id?(cs, true)
  defp is_flake_id?([c | cs], true) when c >= ?A and c <= ?Z, do: is_flake_id?(cs, true)
  defp is_flake_id?([c | cs], true) when c >= ?a and c <= ?z, do: is_flake_id?(cs, true)
  defp is_flake_id?([], true), do: true
  defp is_flake_id?(_, _), do: false

  # -- Ecto.Type API
  @impl Ecto.Type
  def type, do: :uuid

  @impl Ecto.Type
  def cast(value) do
    {:ok, FlakeId.to_string(value)}
  end

  @impl Ecto.Type
  def load(value) do
    {:ok, FlakeId.to_string(value)}
  end

  @impl Ecto.Type
  def dump(value) do
    {:ok, FlakeId.from_string(value)}
  end

  def autogenerate, do: get()

  # -- GenServer API
  def start_link do
    :gen_server.start_link({:local, :flake}, __MODULE__, [], [])
  end

  @impl GenServer
  def init([]) do
    {:ok, %FlakeId{node: worker_id(), time: time()}}
  end

  @impl GenServer
  def handle_call(:get, _from, state) do
    {flake, new_state} = get(time(), state)
    {:reply, flake, new_state}
  end

  # Matches when the calling time is the same as the state time. Incr. sq
  defp get(time, %FlakeId{time: time, node: node, sq: seq}) do
    new_state = %FlakeId{time: time, node: node, sq: seq + 1}
    {gen_flake(new_state), new_state}
  end

  # Matches when the times are different, reset sq
  defp get(newtime, %FlakeId{time: time, node: node}) when newtime > time do
    new_state = %FlakeId{time: newtime, node: node, sq: 0}
    {gen_flake(new_state), new_state}
  end

  # Error when clock is running backwards
  defp get(newtime, %FlakeId{time: time}) when newtime < time do
    {:error, :clock_running_backwards}
  end

  defp gen_flake(%FlakeId{time: time, node: node, sq: seq}) do
    <<time::integer-size(64), node::integer-size(48), seq::integer-size(16)>>
  end

  defp nthchar_base62(n) when n <= 9, do: ?0 + n
  defp nthchar_base62(n) when n <= 35, do: ?A + n - 10
  defp nthchar_base62(n), do: ?a + n - 36

  defp encode_base62(<<integer::integer-size(128)>>) do
    integer
    |> encode_base62([])
    |> List.to_string()
  end

  defp encode_base62(int, acc) when int < 0, do: encode_base62(-int, acc)
  defp encode_base62(int, []) when int == 0, do: '0'
  defp encode_base62(int, acc) when int == 0, do: acc

  defp encode_base62(int, acc) do
    r = rem(int, 62)
    id = div(int, 62)
    acc = [nthchar_base62(r) | acc]
    encode_base62(id, acc)
  end

  defp decode_base62(s) do
    decode_base62(String.to_charlist(s), 0)
  end

  defp decode_base62([c | cs], acc) when c >= ?0 and c <= ?9,
    do: decode_base62(cs, 62 * acc + (c - ?0))

  defp decode_base62([c | cs], acc) when c >= ?A and c <= ?Z,
    do: decode_base62(cs, 62 * acc + (c - ?A + 10))

  defp decode_base62([c | cs], acc) when c >= ?a and c <= ?z,
    do: decode_base62(cs, 62 * acc + (c - ?a + 36))

  defp decode_base62([], acc), do: acc

  defp time do
    {mega_seconds, seconds, micro_seconds} = :erlang.timestamp()
    1_000_000_000 * mega_seconds + seconds * 1000 + :erlang.trunc(micro_seconds / 1000)
  end

  defp worker_id do
    <<worker::integer-size(48)>> = :crypto.strong_rand_bytes(6)
    worker
  end
end
