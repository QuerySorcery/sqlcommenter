defmodule Sqlcommenter do
  @moduledoc """
    Sqlcommenter is a library for adding sqlcommener comments to your ecto queries.

    ## Usage
    Add these callbacks to your Repo module, adjust to your needs.
    The stacktrace option is only required when you plan to include use the extract_repo_caller function.
    This function also accepts the __MODULE__ as the second argument to exclude it from the stacktrace.

   The sqlcommenter option is used for adding static data to the commenent like the running app, team, owner etc.
   Any dynamic data can be added in the prepare_query function. Besides the caller it can also add the trace and span.

  The generated comment needs to be added as comment option - this will be passed to the adapter.

  ```elixir

  def default_options(_operation) do
    [stacktrace: true, prepare: :unnamed, sqlcommenter: [team: "sqlcomm", app: "sqlcomm"]]
  end

  def prepare_query(_operation, query, opts) do
    caller = Sqlcommenter.extract_repo_caller(opts, __MODULE__)

    opts =
      case Keyword.get(opts, :sqlcommenter) do
        nil ->
          opts

        sqlcommenter ->
          [comment: Sqlcommenter.to_str([caller: caller] ++ sqlcommenter)] ++ opts
      end

    {query, opts}
  end
  ```

  Now your postgres logs should look will return a log line like this:

  ```
  2024-10-27 21:43:04.331 GMT,"postgres","sqlcomm_test",416336,"127.0.0.1:53348",671eb3e8.65a50,6,
  "SELECT",2024-10-27 21:43:04 GMT,15/54,61620,LOG,00000,"execute <unnamed>: SELECT u0.""id"",
  u0.""active"", u0.""name"", u0.""inserted_at"", u0.""updated_at"" FROM ""users"" AS
  u0/*app='sqlcomm',caller='Elixir.SqlcommTest.test%20insert%20user%2F1',team='sqlcomm'*/"
  ,,,,,,,,,"","client backend",,0
  ```
  """

  @doc """
  extracts serialized data from query

  ## Example
  iex> query = ~s{SELECT p0."id", p0."first_name" FROM "person"."person" AS p0 /*request_id='fa2af7b2-d8e1-4e8f-8820-3fd648b73187'*/}
  iex> Sqlcommenter.Commenter.deserialize(query)
  %{"request_id" => "fa2af7b2-d8e1-4e8f-8820-3fd648b73187"}
  """
  @spec deserialize(String.t()) :: map()
  def deserialize(query) do
    [_query, data] =
      query
      |> String.trim()
      |> String.trim_trailing("'*/")
      |> String.split("/*")

    data
    |> String.split(",")
    |> Enum.map(fn row ->
      [key, value] = String.split(row, "='")

      {key,
       value
       |> String.trim_trailing("'")
       |> URI.decode()}
    end)
    |> Map.new()
  end

  @doc """
  Encodes enumerable to iodata
  iex> Sqlcommenter.Commenter.to_iodata(controller: :person, function: :index)
  [
      ["controller", "='", "person", "'"],
      ",",
      ["function", "='", "index", "'"]
  ]
  """
  @spec to_iodata(Keyword.t()) :: maybe_improper_list()
  def to_iodata(nil), do: []

  def to_iodata(params) do
    params
    |> Enum.sort(&(&1 <= &2))
    |> sorted_to_iodata()
  end

  @doc """
  The same as to_iodata but it assumes the keys are sorted already.
  """
  @spec sorted_to_iodata(Keyword.t()) :: iodata()
  def sorted_to_iodata(params) do
    for {key, value} <- params, value != nil do
      [
        URI.encode(stringify(key), &URI.char_unreserved?/1),
        "='",
        URI.encode(stringify(value), &URI.char_unreserved?/1),
        "'"
      ]
    end
    |> Enum.intersperse(",")
  end

  @doc """
  Encodes enumerable to string
  iex> Sqlcommenter.Commenter.to_str(controller: :person, function: :index)
  "controller='person',function='index'"
  """
  @spec to_str(Keyword.t()) :: String.t()
  def to_str(params) do
    params
    |> to_iodata()
    |> IO.iodata_to_binary()
  end

  @doc """
  Appends serialized data to query

  iex> query = ["SELECT", [~s{p0."id"}, ", ", ~s{p0."first_name"}], " FROM ", ~s{"person"."person"}, " AS ", "p0"]
  iex> Sqlcommenter.Commenter.append_to_io_query(query, %{controller: :person, function: :index})
  [
    ["SELECT", [~s{p0."id"}, ", ", ~s{p0."first_name"}], " FROM ", ~s{"person"."person"}, " AS ", "p0"],
    " /*",
    [
      ["controller", "='", "person", "'"],
      ",",
      ["function", "='", "index", "'"]
   ],
  "*/"]

  """
  @spec append_to_io_query(iodata, Keyword.t()) :: iodata
  def append_to_io_query(query, params) do
    params
    |> to_iodata()
    |> case do
      [] -> query
      commenter -> [query, " /*", commenter, "*/"]
    end
  end

  @doc """
  Appends serialized data to query

  iex> query = ~s{SELECT p0."id", p0."first_name" FROM "person"."person" AS p0}
  iex> Sqlcommenter.Commenter.append_to_query(query, %{controller: :person, function: :index})
  ~s{SELECT p0.\"id\", p0.\"first_name\" FROM \"person\".\"person\" AS p0 } <>
  "/*controller='person',function='index'*/"

  """
  @spec append_to_query(String.t(), Keyword.t()) :: String.t()
  def append_to_query(query, params) when is_binary(query) do
    query
    |> append_to_io_query(params)
    |> IO.iodata_to_binary()
  end

  defp stringify(value) when is_binary(value), do: value

  defp stringify(value) do
    try do
      to_string(value)
    rescue
      _e ->
        inspect(value)
    end
  end

  @internal_functions [Ecto.Repo.Supervisor, ExUnit.Runner, :timer]
  def extract_repo_caller(opts, repo_module) when is_list(opts) do
    opts
    |> Keyword.get(:stacktrace, [])
    |> Enum.find(fn
      # Skip internal Ecto and standard library calls
      {module, _func, _arity, _} when module in @internal_functions -> false
      {^repo_module, _func, _arity, _} -> false
      # Skip anonymous functions
      {_, "-" <> _func, _, _} -> false
      # Match on the actual caller
      {_module, _func, _arity, _} -> true
    end)
    |> case do
      nil -> nil
      {module, func, arity, _file_info} -> "#{module}.#{func}/#{arity}"
    end
  end
end
