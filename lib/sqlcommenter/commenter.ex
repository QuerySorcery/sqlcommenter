defmodule Sqlcommenter.Commenter do
  @moduledoc """
  Documentation for `Sqlcommenter.Commenter`.
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
end
