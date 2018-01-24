defmodule Mix.Tasks.GenerateConfig do
  use Mix.Task

  @shortdoc "Generates a new config"
  def run(_) do
    IO.puts("Answer a few questions to generate a new config\n")
    IO.puts("--- THIS WILL OVERWRITE YOUR config/generated_config.exs! ---\n")
    domain = IO.gets("What is your domain name? (e.g. pleroma.soykaf.com): ") |> String.trim
    name = IO.gets("What is the name of your instance? (e.g. Pleroma/Soykaf): ") |> String.trim
    email = IO.gets("What's your admin email address: ") |> String.trim
    mediaproxy = IO.gets("Do you want to activate the mediaproxy? (y/N): ")
    |> String.trim()
    |> String.downcase()
    |> String.starts_with?("y")
    proxy_url = if mediaproxy do
      IO.gets("What is the mediaproxy's URL? (e.g. https://cache.example.com): ") |> String.trim
    else
      "https://cache.example.com"
    end
    secret =  :crypto.strong_rand_bytes(64) |> Base.encode64 |> binary_part(0, 64)
    dbpass =  :crypto.strong_rand_bytes(64) |> Base.encode64 |> binary_part(0, 64)

    resultSql = EEx.eval_file("lib/mix/tasks/sample_psql.eex", [dbpass: dbpass])
    result = EEx.eval_file("lib/mix/tasks/sample_config.eex", [domain: domain, email: email, name: name, secret: secret, mediaproxy: mediaproxy, proxy_url: proxy_url, dbpass: dbpass])

    IO.puts("\nWriting config to config/generated_config.exs.\n\nCheck it and configure your database, then copy it to either config/dev.secret.exs or config/prod.secret.exs")
    File.write("config/generated_config.exs", result)
    IO.puts("\nWriting setup_db.psql, please run it as postgre superuser, i.e.: sudo su postgres -c 'psql -f config/setup_db.psql'")
    File.write("config/setup_db.psql", resultSql)
  end
end
