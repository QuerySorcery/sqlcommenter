defmodule SqlcommenterTest do
  use ExUnit.Case
  doctest Sqlcommenter

  describe "append_to_query" do
    test "documetation example" do
      expected =
        "SELECT * FROM FOO /*action='%2Fparam%2Ad',controller='index',framework='spring',traceparent='00-5bd66ef5095369c7b0d1f8f4bd33716a-c532cb4098ac3dd2-01',tracestate='congo%3Dt61rcWkgMzE%2Crojo%3D00f067aa0ba902b7'*/"

      result =
        Sqlcommenter.append_to_query("SELECT * FROM FOO",
          tracestate: "congo=t61rcWkgMzE,rojo=00f067aa0ba902b7",
          traceparent: "00-5bd66ef5095369c7b0d1f8f4bd33716a-c532cb4098ac3dd2-01",
          framework: "spring",
          action: "/param*d",
          controller: "index"
        )

      assert result == expected
    end

    test "escapes meta characters" do
      expected = "SELECT * FROM FOO /*meta='%27%27',sql='DROP%20TABLE%20FOO'*/"

      result =
        Sqlcommenter.append_to_query("SELECT * FROM FOO",
          meta: "''",
          sql: "DROP TABLE FOO"
        )

      assert result == expected
    end

    test "works with maps" do
      expected = "SELECT * FROM FOO /*sql='DROP%20TABLE%20FOO'*/"

      result =
        Sqlcommenter.append_to_query("SELECT * FROM FOO",
          sql: "DROP TABLE FOO"
        )

      assert result == expected
    end

    test "nested data" do
      expected =
        "SELECT * FROM FOO /*action='%2Fparam%2Ad',controller='index',framework='spring',trace='%25%7Bsampled%3A%20true%2C%20span_id%3A%20%22c532cb4098ac3dd2%22%2C%20trace_id%3A%20%225bd66ef5095369c7b0d1f8f4bd33716a%22%2C%20trace_state%3A%20%5B%25%7B%22congo%22%20%3D%3E%20%22t61rcWkgMzE%22%7D%2C%20%25%7B%22rojo%22%20%3D%3E%20%2200f067aa0ba902b7%22%7D%5D%7D'*/"

      result =
        Sqlcommenter.append_to_query("SELECT * FROM FOO",
          controller: "index",
          framework: "spring",
          action: "/param*d",
          trace: %{
            sampled: true,
            span_id: "c532cb4098ac3dd2",
            trace_id: "5bd66ef5095369c7b0d1f8f4bd33716a",
            trace_state: [%{"congo" => "t61rcWkgMzE"}, %{"rojo" => "00f067aa0ba902b7"}]
          }
        )

      assert result == expected
    end
  end

  describe "deserialize" do
    test "deserialize" do
      result =
        Sqlcommenter.deserialize(
          "SELECT * FROM FOO /*action='%2Fparam%2Ad',controller='index',framework='spring',trace='%25%7Bsampled%3A%20true%2C%20span_id%3A%20%22c532cb4098ac3dd2%22%2C%20trace_id%3A%20%225bd66ef5095369c7b0d1f8f4bd33716a%22%2C%20trace_state%3A%20%5B%25%7B%22congo%22%20%3D%3E%20%22t61rcWkgMzE%22%7D%2C%20%25%7B%22rojo%22%20%3D%3E%20%2200f067aa0ba902b7%22%7D%5D%7D'*/"
        )

      expected = %{
        "action" => "/param*d",
        "controller" => "index",
        "framework" => "spring",
        "trace" =>
          "%{sampled: true, span_id: \"c532cb4098ac3dd2\", trace_id: \"5bd66ef5095369c7b0d1f8f4bd33716a\", trace_state: [%{\"congo\" => \"t61rcWkgMzE\"}, %{\"rojo\" => \"00f067aa0ba902b7\"}]}"
      }

      assert result == expected
    end
  end
end
