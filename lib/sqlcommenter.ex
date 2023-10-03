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
  @spec deserialize(String.t()) :: String.t()
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
    [["controller", "='", "person", "'"], ",", "function", "='", "index", "'"],
    "*/"
  ]
  """
  @spec to_iodata(Enumerable.t()) :: String.t()
  def to_iodata(params) do
    iodata =
      for entry <- Enum.sort(params, &(&1 >= &2)), reduce: [] do
        [] -> encode_kv_pair(entry)
        acc -> [encode_kv_pair(entry), "," | acc]
      end

    case IO.iodata_length(iodata) do
      0 -> []
      _ -> [" /*", iodata, "*/"]
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

  iex> query = ~s{SELECT p0."id", p0."first_name" FROM "person"."person" AS p0}
  iex> Sqlcommenter.append_to_query(query, %{controller: :person, function: :index})
  ~s{SELECT p0.\"id\", p0.\"first_name\" FROM \"person\".\"person\" AS p0 } <>
  "/*controller='person',function='index'*/"

  """
  @spec append_to_query(String.t(), Enumerable.t()) :: String.t()
  def append_to_query(query, params) do
    params
    |> to_iodata()
    |> List.insert_at(0, query)
    |> IO.iodata_to_binary()
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
