# Sqlcommenter

Elixir implementation of [sqlcommenter](https://google.github.io/sqlcommenter/) escaping.
Attach SQL comments to correlate user code in ORMs and SQL drivers with SQL statements.

# Installation

The package can be installed by adding `sqlcommenter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sqlcommenter, "~> 0.1.0"}
  ]
end
```

# Usage
After installation modify MyApp.Repo and add a new function:

```elixir
  def all_traced(queryable, opts \\ []) do
      {metadata, opts} = Keyword.pop(opts, :metadata, %{})
    {query, params} = __MODULE__.to_sql(:all, queryable)
    query = Sqlcommenter.append_to_query(query, metadata)
    __MODULE__.query(query, params, opts)
  end
```

Then you can use the new function for querying

```elixir
 Schemas.Person
 |> Repo.all_traced(metadata: %{request_id: Ecto.UUID.generate()})
```

This will reture you your data as usual, additionaly the sql query will be tagged.

```sql
SELECT p0."id", p0."first_name" FROM "person"."person" AS p0 /*request_id='fa2af7b2-d8e1-4e8f-8820-3fd648b73187'*/ []  
```

You can set the options however you want, for example you can pop the supported options by ecto currently:
prefix, timeout, log, telemetry_event, telemetry_options and pass every other value to be appended to the query


Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/sqlcommenter>.

