defmodule Mix.Tasks.Pleroma.OpenapiSpec do
  def run([path]) do
    spec = Pleroma.Web.ApiSpec.spec(server_specific: false) |> Jason.encode!()
    File.write(path, spec)
  end
end
