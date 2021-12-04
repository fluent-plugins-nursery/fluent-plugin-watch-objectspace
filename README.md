# fluent-plugin-watch-objectspace

[Fluentd](https://fluentd.org/) input plugin to collect ObjectSpace information.
Additionally, plugin's process information similar to 
[fluent-plugin-watch-process](https://github.com/y-ken/fluent-plugin-watch-process).

## Installation

### RubyGems

```
$ gem install fluent-plugin-watch-objectspace
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-watch-objectspace"
```

And then execute:

```
$ bundle
```

## Configuration


| parameter      | type              | description                            | default                                           |
|----------------|-------------------|----------------------------------------|---------------------------------------------------|
| watch_class    | array (optional)  | Class to be watched                    |                                                   |
| watch_interval | time (optional)   | Interval to watch object space         | `60`                                              |
| tag            | string (optional) | Tag for this input plugin              | `watch_objectspace`                               |
| modules        | array (optional)  | Modules which must be required         |                                                   |
| watch_delay    | time (optional)   | Delayed seconds until process start up | `60`                                              |
| gc_raw_data    | bool (optional)   | Collect GC::Profiler.raw_data          |                                                   |
| top_fields     | array (optional)  | Specify included fields of top command | `["VIRT", "RES", "SHR", "%CPU", "%MEM", "TIME+"]` |

### \<threshold\> section (optional) (single)

### Configuration

|parameter|type|description|default|
|---|---|---|---|
|memsize_of_all|float (optional)|Threshold rate which regards increased memsize as memory leaks|`1.3`|
|res_of_top|float (optional)|Threshold rate which regards increased RES as memory leaks||


## Usage

```
<source>
  @type watch_objectspace
  tag watch_objectspace
  modules cmetrics
  watch_class CMetrics::Counter, CMetrics::Gauge, CMetrics::Untyped
  watch_interval 60
  watch_delay 10
  <threshold>
    memsize_of_all 1.3
  </threshold>
</source>
```

If memory usage is over 1.3 times, it raise an exception.

## FAQ

### What is the difference between fluent-plugin-watch-objectspace and fluent-plugin-watch-process?

fluent-plugin-watch-process is useful cron/batch process monitoring, In contrast to it, fluent-plugin-watch-objectspace is
focused on used plugin's resource usage especially object and memory.

### Why is alpine not supported?

Because alpine adopts Busybox by default, top -p or alternative ps -q is not supported.

## Copyright

* Copyright(c) 2021- Kentaro Hayashi
* License
  * Apache License, Version 2.0
