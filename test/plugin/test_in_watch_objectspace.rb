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

  sub_test_case "configure" do
    def test_default_configuration
      d = create_driver
      assert_equal([
                     d.instance.watch_class,
                     d.instance.watch_interval,
                     d.instance.watch_delay,
                     d.instance.tag,
                     d.instance.modules,
                     d.instance.gc_raw_data,
                     d.instance.res_incremental_threshold_rate,
                     d.instance.memsize_of_all_incremental_threshold_rate
                   ],
                   [
                     nil,
                     60,
                     60,
                     "watch_objectspace",
                     nil,
                     false,
                     nil,
                     1.3
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
                     d.instance.watch_class,
                     d.instance.watch_interval,
                     d.instance.watch_delay,
                     d.instance.tag,
                     d.instance.modules,
                     d.instance.gc_raw_data,
                     d.instance.res_incremental_threshold_rate,
                     d.instance.memsize_of_all_incremental_threshold_rate
                   ],
                   [
                     ["String"],
                     2.0,
                     1.0,
                     "customized",
                     ["objspace"],
                     true,
                     1.1,
                     1.5
                   ])
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
