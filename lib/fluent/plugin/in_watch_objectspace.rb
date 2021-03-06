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
      desc "Specify included fields of top command"
      config_param :top_fields, :array, default: ["VIRT", "RES", "SHR", "%CPU", "%MEM", "TIME+"]

      config_section :threshold, required: false, multi: false do
        desc "Threshold rate which regards increased memsize as memory leaks"
        config_param :memsize_of_all, :float, default: 1.3
        desc "Threshold rate which regards increased RES as memory leaks"
        config_param :res_of_top, :float, default: nil
      end

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
        if File.readlines("/etc/os-release").any? { |line| line.include?("ID=alpine\n") }
          # alpine's top doesn't support -p option because it uses Busybox
          # ps -q is also not supported. No better way to support it by default.
          raise RuntimeError, "BUG: alpine is not supported"
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
            record["gc_raw_data"] = GC::Profiler.raw_data
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

          check_threshold(record)
          es = OneEventStream.new(Fluent::EventTime.now, record)
          router.emit_stream(@tag, es)
        rescue => e
          $log.error(e.message)
        end
      end

      def check_threshold(record)
        return unless @threshold

        if @threshold.res_of_top
          if @source["res"] * @threshold.res_of_top < record["res"]
            record["memory_leaks"] = true
            message = sprintf("Memory usage is over than expected, threshold res_of_top rate <%f>: %f > %f * %f",
                              @threshold.res_of_top, record["res"],
                              @source["res"], @threshold.res_of_top)
            raise message
          end
        end
        if @threshold.memsize_of_all
          if @source["memsize_of_all"] * @threshold.memsize_of_all < record["memsize_of_all"]
            record["memory_leaks"] = true
            message = sprintf("Memory usage is over than expected, threshold of memsize_of_all rate <%f>: %f > %f * %f",
                              @threshold.memsize_of_all, record["memsize_of_all"],
                              @source["memsize_of_all"], @threshold.memsize_of_all)
            raise message
          end
        end
      end

      def shutdown
      end
    end
  end
end
