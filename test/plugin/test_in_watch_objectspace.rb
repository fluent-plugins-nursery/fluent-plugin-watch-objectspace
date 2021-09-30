require "helper"
require "fluent/plugin/in_watch_objectspace"

class WatchObjectspaceInputTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  DEFAULT_CONFIG = config_element("ROOT", "", {})

  private

  def create_driver(conf = DEFAULT_CONFIG)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::WatchObjectspaceInput).configure(conf)
  end

  def create_config(params={})
    config_element("ROOT", "", params)
  end

  def default_params(data={})
    {
      "watch_delay" => 0,
      "watch_interval" => 1
    }.merge(data)
  end

  sub_test_case "configure" do
    def test_default_configuration
      d = create_driver
      assert_equal([
                     nil,
                     60,
                     60,
                     "watch_objectspace",
                     nil,
                     false
                   ],
                   [
                     d.instance.watch_class,
                     d.instance.watch_interval,
                     d.instance.watch_delay,
                     d.instance.tag,
                     d.instance.modules,
                     d.instance.gc_raw_data
                   ])
    end

    def test_customize
      config = config_element("ROOT", "", {
                                "watch_delay" => 1,
                                "watch_interval" => 2,
                                "watch_class" => ["String"],
                                "tag" => "customized",
                                "modules" => ["objspace"],
                                "gc_raw_data" => true,
                                "res_incremental_threshold_rate" => 1.1,
                                "memsize_of_all_incremental_threshold_rate" => 1.5
                              })
      d = create_driver(config)
      assert_equal([
                     ["String"],
                     2.0,
                     1.0,
                     "customized",
                     ["objspace"],
                     true
                   ],
                   [
                     d.instance.watch_class,
                     d.instance.watch_interval,
                     d.instance.watch_delay,
                     d.instance.tag,
                     d.instance.modules,
                     d.instance.gc_raw_data,
                   ])
    end

    def test_watch_class
      config = create_config(default_params({"watch_class" => ["String"]}))
      d = create_driver(config)
      d.run(expect_records: 1, timeout: 1)
      assert_equal([
                     1,
                     ["string"],
                     true
                   ],
                   [
                     d.events.size,
                     d.events.first.last["count"].keys,
                     d.events.first.last["count"]["string"] > 0
                   ])
    end

    def test_watch_interval
      config = create_config(default_params({"watch_interval" => 5}))
      d = create_driver(config)
      d.run(expect_records: 1, timeout: 5)
      assert_equal(1, d.events.size)
    end

    sub_test_case "watch_delay" do
      data(
        before_interval: [1, 0, 5],
        after_interval: [0, 10, 5]
      )
      test "watch delay" do |(count, delay, interval)|
        config = create_config(default_params({"watch_delay" => delay, "watch_interval" => interval}))
        d = create_driver(config)
        d.run(expect_records: 1, timeout: interval)
        assert_equal(count, d.events.size)
      end
    end

    sub_test_case "tag" do
      data(
        with_tag: ["changed", "changed"],
        default: ["watch_objectspace", nil]
      )
      test "tag" do |(tag, specified)|
        config = if specified
                   create_config(default_params({"tag" => specified}))
                 else
                   create_config(default_params)
                 end
        d = create_driver(config)
        d.run(expect_records: 1, timeout: 5)
        assert_equal([tag], d.events.collect { |event| event.first })
      end
    end

    sub_test_case "modules" do
      def test_invalid_module
        config = create_config(default_params({"modules" => "404",
                                               "watch_class" => "404"}))
        assert_raise do
          create_driver(config)
        end
      end

      def test_valid_module
        config = create_config(default_params({"modules" => "fluent/plugin/in_watch_objectspace",
                                               "watch_class" => "Fluent::Plugin::WatchObjectspaceInput"}))
        d = create_driver(config)
        d.run(expect_records: 1, timeout: 1)
        assert_equal([
                       ["fluent::plugin::watchobjectspaceinput"],
                       true
                     ],
                     [
                       d.events.collect { |event| event.last["count"].keys }.flatten,
                       d.events.all? { |event| event.last["count"]["fluent::plugin::watchobjectspaceinput"] > 0 }
                     ])
      end
    end

    def gc_raw_data_keys(data)
      if data.empty?
        data
      else
        data.collect do |raw_data|
          raw_data.keys
        end
      end
    end

    sub_test_case "gc_raw_data" do
      data(
        without_gc: [false, [[]]],
        with_gc: [true, [[%i(GC_FLAGS GC_TIME GC_INVOKE_TIME HEAP_USE_SIZE HEAP_TOTAL_SIZE HEAP_TOTAL_OBJECTS GC_IS_MARKED)]]]
      )
      test "gc" do |(gc, keys)|
        config = create_config(default_params({"gc_raw_data" => "true"}))
        d = create_driver(config)
        GC.start if gc
        d.run(expect_records: 1, timeout: 1)
        assert_equal([
                       1,
                       keys
                     ],
                     [
                       d.events.size,
                       d.events.collect { |event| gc_raw_data_keys(event.last["gc_raw_data"])},
                     ])
      end
    end

  end

  sub_test_case "parser" do
    def test_top_parser
      config = config_element("ROOT", "", {
                                "watch_delay" => 0,
                                "watch_interval" => 5,
                                "watch_class" => ["String"]})
      d = create_driver(config)
      d.run(expect_records: 1, timeout:5)
      event = d.events.first
      assert_equal([1,
                    "watch_objectspace",
                    Fluent::EventTime,
                    ["pid", "count", "memory_leaks", "memsize_of_all", "virt", "res", "shr", "%cpu", "%mem", "time+"]
                   ],
                   [d.events.size,
                    event[0],
                    event[1].class,
                    event[2].keys])
    end
  end
end
