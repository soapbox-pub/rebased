defmodule Pleroma.Web.Router do
  use Pleroma.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", Pleroma.Web do
    pipe_through :api
  end
end
