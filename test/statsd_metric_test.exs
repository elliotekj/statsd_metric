defmodule StatsdMetricTest do
  use ExUnit.Case
  doctest StatsdMetric

  describe "encode/3" do
    test "encodes a basic metric" do
      assert StatsdMetric.encode("namespaced.value", 10, :counter) == [
               "namespaced.value",
               58,
               "10",
               124,
               "c"
             ]
    end
  end

  describe "encode_to_string/3" do
    test "encodes a basic metric" do
      assert StatsdMetric.encode_to_string("namespaced.value", 10, :counter) ==
               "namespaced.value:10|c"

      assert StatsdMetric.encode_to_string("namespaced.value", 1.0, :gauge) ==
               "namespaced.value:1.0|g"

      assert StatsdMetric.encode_to_string("namespaced.value", 512, :histogram) ==
               "namespaced.value:512|h"

      assert StatsdMetric.encode_to_string("namespaced.value", 250, :timer) ==
               "namespaced.value:250|ms"

      assert StatsdMetric.encode_to_string("namespaced.value", 192.16, :set) ==
               "namespaced.value:192.16|s"

      assert StatsdMetric.encode_to_string("namespaced.value", 18.5, :meter) ==
               "namespaced.value:18.5|m"
    end

    test "encodes a metric with a sample rate and tags" do
      tags = [node: node(), tagged: true]
      sample_rate = 1.0
      options = [sample_rate: sample_rate, tags: tags]

      assert StatsdMetric.encode_to_string("namespaced.value", 10, :counter, options) ==
               "namespaced.value:10|c|@1.0|#node:nonode@nohost,tagged:true"
    end

    test "encodes a metric with a sample rate" do
      assert StatsdMetric.encode_to_string("namespaced.value", 10, :counter, sample_rate: 1.0) ==
               "namespaced.value:10|c|@1.0"
    end

    test "encodes a metric with tags as keyword list" do
      tags = [node: node(), tagged: true]

      assert StatsdMetric.encode_to_string("namespaced.value", 10, :counter, tags: tags) ==
               "namespaced.value:10|c|#node:nonode@nohost,tagged:true"
    end

    test "encodes a metric with tags as strings" do
      tags = ["node:#{node()}", "tagged:true"]

      assert StatsdMetric.encode_to_string("namespaced.value", 10, :counter, tags: tags) ==
               "namespaced.value:10|c|#node:nonode@nohost,tagged:true"
    end

    test "encodes a metric with a tag" do
      tags = [node: node()]

      assert StatsdMetric.encode_to_string("namespaced.value", 10, :counter, tags: tags) ==
               "namespaced.value:10|c|#node:nonode@nohost"
    end
  end

  describe "decode" do
    test "decodes a basic metric" do
      assert StatsdMetric.decode!("namespaced.value:10|c") == %StatsdMetric{
               key: "namespaced.value",
               value: 10.0,
               type: :counter
             }

      assert StatsdMetric.decode!("namespaced.value:1.0|g") == %StatsdMetric{
               key: "namespaced.value",
               value: 1.0,
               type: :gauge
             }

      assert StatsdMetric.decode!("namespaced.value:512|h") == %StatsdMetric{
               key: "namespaced.value",
               value: 512.0,
               type: :histogram
             }

      assert StatsdMetric.decode!("namespaced.value:250|ms") == %StatsdMetric{
               key: "namespaced.value",
               value: 250.0,
               type: :timer
             }

      assert StatsdMetric.decode!("namespaced.value:192.16|s") == %StatsdMetric{
               key: "namespaced.value",
               value: 192.16,
               type: :set
             }

      assert StatsdMetric.decode!("namespaced.value:18.5|m") == %StatsdMetric{
               key: "namespaced.value",
               value: 18.5,
               type: :meter
             }
    end

    test "decodes a metric with a sample rate and tags" do
      assert StatsdMetric.decode!("namespaced.value:10|c|@1.0|#node:nonode@nohost,tagged:true") ==
               %StatsdMetric{
                 key: "namespaced.value",
                 value: 10.0,
                 type: :counter,
                 sample_rate: 1.0,
                 tags: %{
                   "node" => "nonode@nohost",
                   "tagged" => "true"
                 }
               }
    end

    test "decodes a metric with a sample rate" do
      assert StatsdMetric.decode!("namespaced.value:10|c|@1.0") ==
               %StatsdMetric{
                 key: "namespaced.value",
                 value: 10.0,
                 type: :counter,
                 sample_rate: 1.0
               }
    end

    test "decodes a metric with tags" do
      assert StatsdMetric.decode!("namespaced.value:-10|c|#node:nonode@nohost,tagged:true") ==
               %StatsdMetric{
                 key: "namespaced.value",
                 value: -10.0,
                 type: :counter,
                 tags: %{
                   "node" => "nonode@nohost",
                   "tagged" => "true"
                 }
               }
    end

    test "decodes a metric with a single tag" do
      assert StatsdMetric.decode!("namespaced.value:10|c|#node:nonode@nohost") ==
               %StatsdMetric{
                 key: "namespaced.value",
                 value: 10.0,
                 type: :counter,
                 tags: %{"node" => "nonode@nohost"}
               }
    end

    test "errors on an empty metric" do
      assert_raise(StatsdMetric.EmptyError, fn -> StatsdMetric.decode!("") end)
    end

    test "errors on a metric with no key" do
      assert_raise(StatsdMetric.NoKeyError, fn -> StatsdMetric.decode!(":10|c") end)
    end

    test "errors on a metric with no value" do
      assert_raise(StatsdMetric.NoValueError, fn -> StatsdMetric.decode!("namespaced.value|c") end)

      assert_raise(StatsdMetric.NoValueError, fn ->
        StatsdMetric.decode!("namespaced.value:|c")
      end)
    end

    test "errors on a metric with invalid value" do
      assert_raise(StatsdMetric.BadValueError, fn -> StatsdMetric.decode!("namespaced.value:string|c") end)
    end

    test "errors on a metric with no type" do
      assert_raise(StatsdMetric.NoTypeError, fn ->
        StatsdMetric.decode!("namespaced.value:10|")
      end)

      assert_raise(StatsdMetric.NoTypeError, fn -> StatsdMetric.decode!("namespaced.value:10") end)
    end
  end
end
