defmodule Sqlcommenter do
  @moduledoc """
  Documentation for `Sqlcommenter`.
  """

  @doc """
  extracts serialized data from query
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
  """
  @spec to_iodata(Enumerable.t()) :: String.t()
  def to_iodata(params) do
    iodata =
      for entry <- Enum.sort(params, &(&1 >= &2)), reduce: [] do
        [] -> encode_kv_pair(entry)
        acc -> [encode_kv_pair(entry), "," | acc]
      end

    case IO.iodata_length(iodata) do
      0 -> ""
      _ -> [" /*", iodata, "*/"]
    end
  end

  @doc """
  Encodes enumerable to string
  """
  @spec to_str(Enumerable.t()) :: String.t()
  def to_str(params) do
    params
    |> to_iodata()
    |> IO.iodata_to_binary()
  end

  @doc """
  Appends serialized data to query
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
