# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emails.Mailer do
  @moduledoc """
  Defines the Pleroma mailer.

  The module contains functions to delivery email using Swoosh.Mailer.
  """

  alias Pleroma.Workers.MailerWorker
  alias Swoosh.DeliveryError

  @otp_app :pleroma
  @mailer_config [otp: :pleroma]

  @spec enabled?() :: boolean()
  def enabled?, do: Pleroma.Config.get([__MODULE__, :enabled])

  @doc "add email to queue"
  def deliver_async(email, config \\ []) do
    encoded_email =
      email
      |> :erlang.term_to_binary()
      |> Base.encode64()

    MailerWorker.enqueue("email", %{"encoded_email" => encoded_email, "config" => config})
  end

  @doc "callback to perform send email from queue"
  def perform(:deliver_async, email, config), do: deliver(email, config)

  @spec deliver(Swoosh.Email.t(), Keyword.t()) :: {:ok, term} | {:error, term}
  def deliver(email, config \\ [])

  def deliver(email, config) do
    case enabled?() do
      true -> Swoosh.Mailer.deliver(email, parse_config(config))
      false -> {:error, :deliveries_disabled}
    end
  end

  @spec deliver!(Swoosh.Email.t(), Keyword.t()) :: term | no_return
  def deliver!(email, config \\ [])

  def deliver!(email, config) do
    case deliver(email, config) do
      {:ok, result} -> result
      {:error, reason} -> raise DeliveryError, reason: reason
    end
  end

  @on_load :validate_dependency

  @doc false
  def validate_dependency do
    parse_config([])
    |> Keyword.get(:adapter)
    |> Swoosh.Mailer.validate_dependency()
  end

  defp parse_config(config) do
    Swoosh.Mailer.parse_config(@otp_app, __MODULE__, @mailer_config, config)
  end
end
