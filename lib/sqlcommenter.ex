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
  Appends serialized data to query
  """
  @spec serialize(String.t(), Enumerable.t()) :: String.t()
  def serialize(query, params) do
    escaped =
      params
      |> Enum.sort()
      |> Enum.map_join(",", &encode_kv_pair/1)

    query <> " /*" <> escaped <> "*/"
  end

  defp encode_kv_pair({key, value}) do
    URI.encode(stringify(key), &URI.char_unreserved?/1) <>
      "='" <> URI.encode(stringify(value), &URI.char_unreserved?/1) <> "'"
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
