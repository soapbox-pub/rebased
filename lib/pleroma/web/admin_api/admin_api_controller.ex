defmodule Pleroma.Web.AdminAPI.Controller do
  use Pleroma.Web, :controller

  require Logger

  action_fallback(:errors)

  def user_delete(%{assigns: %{user: user}} = conn, _params) do
  end

  def user_create(%{assigns: %{user: user}} = conn, _params) do
  end

  def relay_follow(%{assigns: %{user: user}} = conn, _params) do
  end

  def relay_unfollow(%{assigns: %{user: user}} = conn, _params) do
  end

  def user_delete(%{assigns: %{user: user}} = conn, _params) do
  end

  def user_delete(%{assigns: %{user: user}} = conn, _params) do
  end
end
