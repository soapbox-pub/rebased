# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.WelcomeEmail do
  @moduledoc """
  The module represents the functions to send welcome email.
  """

  alias Pleroma.Config
  alias Pleroma.Emails
  alias Pleroma.User

  import Pleroma.Config.Helpers, only: [instance_name: 0]

  @spec enabled?() :: boolean()
  def enabled?, do: Config.get([:welcome, :email, :enabled], false)

  @spec send_email(User.t()) :: {:ok, Oban.Job.t()}
  def send_email(%User{} = user) do
    user
    |> Emails.UserEmail.welcome(email_options(user))
    |> Emails.Mailer.deliver_async()
  end

  defp email_options(user) do
    bindings = [user: user, instance_name: instance_name()]

    %{}
    |> add_sender(Config.get([:welcome, :email, :sender], nil))
    |> add_option(:subject, bindings)
    |> add_option(:html, bindings)
    |> add_option(:text, bindings)
  end

  defp add_option(opts, option, bindings) do
    [:welcome, :email, option]
    |> Config.get(nil)
    |> eval_string(bindings)
    |> merge_options(opts, option)
  end

  defp add_sender(opts, {_name, _email} = sender) do
    merge_options(sender, opts, :sender)
  end

  defp add_sender(opts, sender) when is_binary(sender) do
    add_sender(opts, {instance_name(), sender})
  end

  defp add_sender(opts, _), do: opts

  defp merge_options(nil, options, _option), do: options

  defp merge_options(value, options, option) do
    Map.merge(options, %{option => value})
  end

  defp eval_string(nil, _), do: nil
  defp eval_string("", _), do: nil
  defp eval_string(str, bindings), do: EEx.eval_string(str, bindings)
end
