# Optimizing the BEAM

Pleroma is built upon the Erlang/OTP VM known as BEAM. The BEAM VM is highly optimized for latency, but this has drawbacks in environments without dedicated hardware. One of the tricks used by the BEAM VM is [busy waiting](https://en.wikipedia.org/wiki/Busy_waiting). This allows the application to pretend to be busy working so the OS kernel does not pause the application process and switch to another process waiting for the CPU to execute its workload. It does this by spinning for a period of time which inflates the apparent CPU usage of the application so it is immediately ready to execute another task. This can be observed with utilities like **top(1)** which will show consistently high CPU usage for the process. Switching between procesess is a rather expensive operation and also clears CPU caches further affecting latency and performance. The goal of busy waiting is to avoid this penalty.

This strategy is very successful in making a performant and responsive application, but is not desirable on Virtual Machines or hardware with few CPU cores. Pleroma instances are often deployed on the same server as the required PostgreSQL database which can lead to situations where the Pleroma application is holding the CPU in a busy-wait loop and as a result the database cannot process requests in a timely manner. The fewer CPUs available, the more this problem is exacerbated. The latency is further amplified by the OS being installed on a Virtual Machine as the Hypervisor uses CPU time-slicing to pause the entire OS and switch between other tasks.

More adventurous admins can be creative with CPU affinity (e.g., *taskset* for Linux and *cpuset* on FreeBSD) to pin processes to specific CPUs and eliminate much of this contention. The most important advice is to run as few processes as possible on your server to achieve the best performance. Even idle background processes can occasionally create [software interrupts](https://en.wikipedia.org/wiki/Interrupt) and take attention away from the executing process creating latency spikes and invalidation of the CPU caches as they must be cleared when switching between processes for security.

Please only change these settings if you are experiencing issues or really know what you are doing. In general, there's no need to change these settings.

## VPS Provider Recommendations

### Good

* Hetzner Cloud

### Bad

* AWS (known to use burst scheduling)


## Example configurations

Tuning the BEAM requires you provide a config file normally called [vm.args](http://erlang.org/doc/man/erl.html#emulator-flags). If you are using systemd to manage the service you can modify the unit file as such:

`ExecStart=/usr/bin/elixir --erl '-args_file /opt/pleroma/config/vm.args' -S /usr/bin/mix phx.server`

Check your OS documentation to adopt a similar strategy on other platforms.

### Virtual Machine and/or few CPU cores

Disable the busy-waiting. This should generally only be done if you're on a platform that does burst scheduling, like AWS.

**vm.args:**

```
+sbwt none
+sbwtdcpu none
+sbwtdio none
```

### Dedicated Hardware

Enable more busy waiting, increase the internal maximum limit of BEAM processes and ports. You can use this if you run on dedicated hardware, but it is not necessary.

**vm.args:**

```
+P 16777216
+Q 16777216
+K true
+A 128
+sbt db
+sbwt very_long
+swt very_low
+sub true
+Mulmbcs 32767
+Mumbcgs 1
+Musmbcs 2047
```

## Additional Reading

* [WhatsApp: Scaling to Millions of Simultaneous Connections](https://www.erlang-factory.com/upload/presentations/558/efsf2012-whatsapp-scaling.pdf)
* [Preemptive Scheduling and Spinlocks](https://www.uio.no/studier/emner/matnat/ifi/nedlagte-emner/INF3150/h03/annet/slides/preemptive.pdf)
* [The Curious Case of BEAM CPU Usage](https://stressgrid.com/blog/beam_cpu_usage/)
