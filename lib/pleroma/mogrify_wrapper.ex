# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MogrifyWrapper do
  @moduledoc """
  Default implementation of MogrifyBehaviour that delegates to Mogrify.
  """
  @behaviour Pleroma.MogrifyBehaviour

  @impl true
  def open(file) do
    Mogrify.open(file)
  end

  @impl true
  def custom(image, action) do
    Mogrify.custom(image, action)
  end

  @impl true
  def custom(image, action, options) do
    Mogrify.custom(image, action, options)
  end

  @impl true
  def save(image, opts) do
    Mogrify.save(image, opts)
  end
end
