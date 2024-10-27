defmodule Sqlcommenter do
  @moduledoc """
    Sqlcommenter is a library for adding sqlcommener comments to your ecto queries

    ## Usage
    Install the library.
    If your app is managing the migrations for your ecto repo you will need to follow these steps:
    Duplicate the repo config in your to include this repo. It should be identical as the
    exising Repo.  Duplicate your existing MyApp.Repo module to MyApp.MigrationsRepo.  Add a
    config option to point to your exisiting migrations folder in MigrationsRepo in existing
    Repo change use to use Sqlcommenter.Repo.  add any static sqlcommenter options that will
    be included in all calls to the Repo config.

   At then end you will end up with 2 Repo modules just like this:

  ```
  defmodule Repo do
    use Sqlcommenter.Repo,
      otp_app: :my_app,
      adapter: Ecto.Adapters.Postgres,
      sqlcommenter: [app: "test_app", owner: "team_c"]
  end

  defmodule MigrationRepo do
    use Ecto.Repo,
      otp_app: :my_app,
      adapter: Ecto.Adapters.Postgres,
      priv: "priv/repo"
  end
  ``

  The Sqlcommenter.Repo uses macros under the hood to get additional data from the caller so
  it needs to be required everywhere where it is used

  ```
  require MyApp.Repo
  alias MyApp.Repo
  ```

  You can then use the Repo as normal.  The Sqlcommenter.Repo will add the sqlcommenter comment
  to the query.



  ```
  defmodule W do
    require Test.Repo

    def get do
      Test.Repo.all(Weather)
    end
  end

  W.get()
  ```
  will return a log line like this:
  ```
  2024-10-26 09:21:27.368
  BST,"postgres","postgres",89302,"127.0.0.1:56568",671ca5a8.15cd6,1,"SELECT",2024-10-26
  09:17:44 BST,9/37,0,LOG,00000,"execute <unnamed>: SELECT
  w0.""id"", v1.""name"" FROM ""weather"" AS w0 INNER JOIN (VALUES
  ($1::bigint,$2::varchar),($3::bigint,$4::varchar)) AS v1 (""id"",""name"") ON v1.""id"" =
  w0.""id""/*app='test_app',function='get%2F0',line='11',module='W',owner='team_c'*/","parameters:
  $1 = '1', $2 = 'zabrze', $3 = '2', $4 = 'dudley'",,,,,,,,"","client backend",,0
  """
end
