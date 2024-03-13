defmodule Sqlcommenter do
  @moduledoc """
  Documentation for `Sqlcommenter`.
  """

  @doc """
  extracts serialized data from query

  ## Example
  iex> query = ~s{SELECT p0."id", p0."first_name" FROM "person"."person" AS p0 /*request_id='fa2af7b2-d8e1-4e8f-8820-3fd648b73187'*/}
  iex> Sqlcommenter.deserialize(query)
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
  iex> Sqlcommenter.to_iodata(controller: :person, function: :index)
  [
    " /*",
    [
      ["controller", "='", "person", "'"],
      ",",
      ["function", "='", "index", "'"]
    ],
    "*/"
  ]
  """
  @spec to_iodata(Enumerable.t() | nil) :: maybe_improper_list()
  def to_iodata(nil), do: []

  def to_iodata(params) do
    params
    |> Enum.sort(&(&1 <= &2))
    |> Enum.reject(fn {_k, val} -> val == nil end)
    |> Enum.map(&encode_kv_pair(&1))
    |> Enum.intersperse(",")
    |> case do
      [] -> []
      iodata -> [" /*", iodata, "*/"]
    end
  end

  @doc """
  Encodes enumerable to string
  iex> Sqlcommenter.to_str(controller: :person, function: :index)
  " /*controller='person',function='index'*/"
  """
  @spec to_str(Enumerable.t()) :: String.t()
  def to_str(params) do
    params
    |> to_iodata()
    |> IO.iodata_to_binary()
  end

  @doc """
  Appends serialized data to query

  iex> query = ["SELECT", [~s{p0."id"}, ", ", ~s{p0."first_name"}], " FROM ", ~s{"person"."person"}, " AS ", "p0"]
  iex> Sqlcommenter.append_to_io_query(query, %{controller: :person, function: :index})
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
  @spec append_to_io_query(String.t(), Enumerable.t() | nil) :: String.t()
  def append_to_io_query(query, params) do
    params
    |> to_iodata()
    |> case do
      [] -> query
      commenter -> [query | commenter]
    end
  end

  @doc """
  Appends serialized data to query

  iex> query = ~s{SELECT p0."id", p0."first_name" FROM "person"."person" AS p0}
  iex> Sqlcommenter.append_to_query(query, %{controller: :person, function: :index})
  ~s{SELECT p0.\"id\", p0.\"first_name\" FROM \"person\".\"person\" AS p0 } <>
  "/*controller='person',function='index'*/"

  """
  @spec append_to_query(String.t(), Enumerable.t() | nil) :: String.t()
  def append_to_query(query, params) when is_binary(query) do
    params
    |> to_iodata()
    |> case do
      [] -> query
      commenter -> IO.iodata_to_binary([query, commenter])
    end
  end

  defp encode_kv_pair({key, value}) do
    [
      URI.encode(stringify(key), &URI.char_unreserved?/1),
      "='",
      URI.encode(stringify(value), &URI.char_unreserved?/1),
      "'"
    ]
  end

  defp stringify(value) do
    try do
      to_string(value)
    rescue
      _e ->
        inspect(value)
    end
  end
end
