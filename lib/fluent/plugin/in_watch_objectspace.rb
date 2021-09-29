#
# Copyright 2021- Kentaro Hayashi
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "fluent/plugin/input"
require "fluent/config/error"
require "objspace"

module Fluent
  module Plugin
    class WatchObjectspaceInput < Fluent::Plugin::Input
      Fluent::Plugin.register_input("watch_objectspace", self)

      helpers :timer

      desc "Class to be watched"
      config_param :watch_class, :array, default: nil
      desc "Interval to watch object space"
      config_param :watch_interval, :time, default: 60
      desc "Tag for this input plugin"
      config_param :tag, :string, default: "watch_objectspace"
      desc "Modules which must be required"
      config_param :modules, :array, default: nil
      desc "Delayed seconds until process start up"
      config_param :watch_delay, :time, default: 60
      desc "Collect GC::Profiler.raw_data"
      config_param :gc_raw_data, :bool, default: false
      desc "Threshold rate which regards increased RES as memory leaks"
      config_param :res_incremental_threshold_rate, :float, default: nil
      desc "Threshold rate which regards increased memsize as memory leaks"
      config_param :memsize_of_all_incremental_threshold_rate, :float, default: 1.3
      desc "Specify included fields of top command"
      config_param :top_fields, :array, default: ["VIRT", "RES", "SHR", "%CPU", "%MEM", "TIME+"]
     
      def configure(conf)
        super(conf)
        if @modules
          @modules.each do |mod|
            begin
              require mod
            rescue LoadError
              raise Fluent::ConfigError.new("BUG: module <#{mod}> can't be loaded")
            end
          end
        end
        @warmup_time = Time.now + @watch_delay
        @source = {}
        GC::Profiler.enable
      end

      def start
        super
        timer_execute(:execute_watch_objectspace, @watch_interval, &method(:refresh_watchers))
      end

      def parse_top_result(content)
        record = {}
        fields = content.split("\n")[-2].split
        values = content.split("\n").last.split
        fields.each_with_index do |field, index|
          next unless @top_fields.include?(field)
          case field
          when "USER", "S", "TIME+", "COMMAND"
            record[field.downcase] = values[index]
          when "PID", "PR", "NI", "VIRT", "RES", "SHR"
            record[field.downcase] = values[index].to_i
          else
            record[field.downcase] = values[index].to_f
          end
        end
        record
      end

      def refresh_watchers
        return if Time.now < @warmup_time
        
        pid = Process.pid
        record = {
          "pid" => pid,
          "count" => {},
          "memory_leaks" => false,
          "memsize_of_all" => ObjectSpace.memsize_of_all
        }

        begin
          content = IO.popen("top -p #{pid} -b -n 1") do |io|
            io.read
          end
          record.merge!(parse_top_result(content))

          if @gc_raw_data
            record["raw_data"] = GC::Profiler.raw_data
          end
          if @watch_class
            @watch_class.each do |klass|
              record["count"]["#{klass.downcase}"] = ObjectSpace.each_object(Object.const_get(klass)) { |x| x }
            end
          end

          if @source.empty?
            record["memsize_of_all"] = ObjectSpace.memsize_of_all
            @source = record
          end

          if @res_incremental_threshold_rate
            if @source["res"] * @res_incremental_threshold_rate < record["res"]
              record["memory_leaks"] = true
              message = sprintf("Memory leak is detected, threshold rate <%f>: %f > %f * %f",
                                @res_incremental_threshold_rate, record["res"],
                                @source["res"], @res_incremental_threshold_rate)
              raise message
            end
          end
          if @source["memsize_of_all"] * @memsize_of_all_incremental_threshold_rate < record["memsize_of_all"]
            record["memory_leaks"] = true
            message = sprintf("Memory leak is detected, threshold rate <%f>: %f > %f * %f",
                              @memsize_of_all_incremental_threshold_rate, record["memsize_of_all"],
                              @source["memsize_of_all"], @memsize_of_all_incremental_threshold_rate)
            raise message
          end
          es = OneEventStream.new(Fluent::EventTime.now, record)
          router.emit_stream(@tag, es)
        rescue => e
          $log.error(e.message)
        end
      end

      def shutdown
      end
    end
  end
end
