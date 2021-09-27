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


| parameter                      | type              | description                                                | default             |
|--------------------------------|-------------------|------------------------------------------------------------|---------------------|
| watch_class                    | array (optional)  | Class to be watched                                        |                     |
| watch_interval                 | time (optional)   | Interval to watch object space                             | `60`                |
| tag                            | string (optional) | Tag for this input plugin                                  | `watch_objectspace` |
| modules                        | array (optional)  | Modules which must be required                             |                     |
| watch_delay                    | time (optional)   | Delayed seconds until process start up                     | `60`                |
| gc_raw_data                    | bool (optional)   | Collect GC::Profiler.raw_data                              |                     |
| res_incremental_threshold_rate | float (optional)  | Threshold rate which regards increased RES as memory leaks | `1.3`               |

## Usage


```
<source>
  @type watch_objectspace
  tag watch_objectspace
  modules cmetrics
  watch_class CMetrics::Counter, CMetrics::Gauge, CMetrics::Untyped
  watch_interval 60
  watch_delay 10
  res_incremental_threshold_rate 1.3
</source>
```

If memory usage is over 1.3 times, it raise an exception.

## FAQ

### What is the difference between fluent-plugin-watch-objectspace and fluent-plugin-watch-process?

fluent-plugin-watch-process is useful cron/batch process monitoring, In contrast to it, fluent-plugin-watch-objectspace is
focused on used plugin's resource (memory) usage especially object and memory.

## Copyright

* Copyright(c) 2021- Kentaro Hayashi
* License
  * Apache License, Version 2.0
