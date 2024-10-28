# Installation

The package can be installed by adding `sqlcommenter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sqlcommenter, "~> 0.1.0"}
  ]
end
```

<!-- MDOC !-->

# Sqlcommenter

Disclaimer: Currently using comments disables prepared statements and may increase cpu load on
your database.
Elixir implementation of [sqlcommenter](https://google.github.io/sqlcommenter/) escaping.
Attach SQL comments to correlate user code in ORMs and SQL drivers with SQL statements.

## Usage
  Add these callbacks to your Repo module, adjust to your needs.
  The stacktrace option is only required when you plan to include use the extract_repo_caller
  function.  This function also accepts the __MODULE__ as the second argument to exclude it
  from the stacktrace.

 The sqlcommenter option is used for adding static data to the comment like the running app,
 team, owner etc.  Any dynamic data can be added in the prepare_query function. Besides the
 caller it can also add the trace and span.

The generated comment needs to be added as comment option - this will be passed to the adapter.

```elixir

def default_options(_operation) do
  [stacktrace: true, prepare: :unnamed, sqlcommenter: [team: "sqlcomm", app: "sqlcomm"]]
end

def prepare_query(_operation, query, opts) do
  sqlcommennter_defaults = Keyword.get(opts, :sqlcommenter)
  caller = Sqlcommenter.extract_repo_caller(opts, __MODULE__)
  comment = Sqlcommenter.to_str([caller: caller] ++ sqlcommenter_defaults)

  {query, [comment: comment] ++ opts}
end
```

Now your postgres logs should look will return a log line like this:

```
2024-10-27 21:43:04.331 GMT,"postgres","sqlcomm_test",416336,"127.0.0.1:53348",671eb3e8.65a50,6, "SELECT",2024-10-27 21:43:04 GMT,15/54,61620,LOG,00000,"execute <unnamed>: SELECT u0.""id"",
u0.""active"", u0.""name"", u0.""inserted_at"", u0.""updated_at"" FROM ""users"" AS
u0/*app='sqlcomm',caller='Elixir.SqlcommTest.test%20insert%20user%2F1',team='sqlcomm'*/"
,,,,,,,,,"","client backend",,0
```

Alternatively, when you're concerned about performance and your options are mostly static
you can also omit the Sqlcommenter logic and write your own custom function.
Just remember that according the sqlcommenter specs the keys must be sorted.

```elixir
defmodule SqlEEx do
   require EEx

  EEx.function_from_string(
    :def,
    :to_comment,
    "app:'sqlcomm',caller:'<%= caller %>'team:'sqlcomm'",
    [:caller]
  )
end
```

And then use it in your repo:
```elixir
def prepare_query(_operation, query, opts) do
  caller = Sqlcommenter.extract_repo_caller(opts, __MODULE__)
  SqlEEx.to_comment(caller: caller)
  {query, [comment: comment] ++ opts}
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/sqlcommenter>.

