Title: tokio - Rust

URL Source: https://docs.rs/tokio

Markdown Content:
Expand description

A runtime for writing reliable network applications without compromising speed.

Tokio is an event-driven, non-blocking I/O platform for writing asynchronous applications with the Rust programming language. At a high level, it provides a few major components:

*   Tools for [working with asynchronous tasks](https://docs.rs/tokio#working-with-tasks), including [synchronization primitives and channels](https://docs.rs/tokio/latest/tokio/sync/index.html "mod tokio::sync") and [timeouts, sleeps, and intervals](https://docs.rs/tokio/latest/tokio/time/index.html "mod tokio::time").
*   APIs for [performing asynchronous I/O](https://docs.rs/tokio#asynchronous-io), including [TCP and UDP](https://docs.rs/tokio/latest/tokio/net/index.html "mod tokio::net") sockets, [filesystem](https://docs.rs/tokio/latest/tokio/fs/index.html "mod tokio::fs") operations, and [process](https://docs.rs/tokio/latest/tokio/process/index.html "mod tokio::process") and [signal](https://docs.rs/tokio/latest/tokio/signal/index.html "mod tokio::signal") management.
*   A [runtime](https://docs.rs/tokio/latest/tokio/runtime/index.html "mod tokio::runtime") for executing asynchronous code, including a task scheduler, an I/O driver backed by the operating system’s event queue (`epoll`, `kqueue`, `IOCP`, etc…), and a high performance timer.

Guide level documentation is found on the [website](https://tokio.rs/tokio/tutorial).

## [§](https://docs.rs/tokio#a-tour-of-tokio)A Tour of Tokio

Tokio consists of a number of modules that provide a range of functionality essential for implementing asynchronous applications in Rust. In this section, we will take a brief tour of Tokio, summarizing the major APIs and their uses.

The easiest way to get started is to enable all features. Do this by enabling the `full` feature flag:

`tokio = { version = "1", features = ["full"] }`

Tokio is great for writing applications and most users in this case shouldn’t worry too much about what features they should pick. If you’re unsure, we suggest going with `full` to ensure that you don’t run into any road blocks while you’re building your application.

##### [§](https://docs.rs/tokio#example)Example

This example shows the quickest way to get started with Tokio.

`tokio = { version = "1", features = ["full"] }`

#### [§](https://docs.rs/tokio#authoring-libraries)Authoring libraries

As a library author your goal should be to provide the lightest weight crate that is based on Tokio. To achieve this you should ensure that you only enable the features you need. This allows users to pick up your crate without having to enable unnecessary features.

##### [§](https://docs.rs/tokio#example-1)Example

This example shows how you may want to import features for a library that just needs to `tokio::spawn` and use a `TcpStream`.

`tokio = { version = "1", features = ["rt", "net"] }`

### [§](https://docs.rs/tokio#working-with-tasks)Working With Tasks

Asynchronous programs in Rust are based around lightweight, non-blocking units of execution called [_tasks_](https://docs.rs/tokio#working-with-tasks). The [`tokio::task`](https://docs.rs/tokio/latest/tokio/task/index.html "mod tokio::task") module provides important tools for working with tasks:

*   The [`spawn`](https://docs.rs/tokio/latest/tokio/task/fn.spawn.html "fn tokio::task::spawn") function and [`JoinHandle`](https://docs.rs/tokio/latest/tokio/task/struct.JoinHandle.html "struct tokio::task::JoinHandle") type, for scheduling a new task on the Tokio runtime and awaiting the output of a spawned task, respectively,
*   Functions for [running blocking operations](https://docs.rs/tokio/latest/tokio/task/index.html#blocking-and-yielding) in an asynchronous task context.

The [`tokio::task`](https://docs.rs/tokio/latest/tokio/task/index.html "mod tokio::task") module is present only when the “rt” feature flag is enabled.

The [`tokio::sync`](https://docs.rs/tokio/latest/tokio/sync/index.html "mod tokio::sync") module contains synchronization primitives to use when needing to communicate or share data. These include:

*   channels ([`oneshot`](https://docs.rs/tokio/latest/tokio/sync/oneshot/index.html "mod tokio::sync::oneshot"), [`mpsc`](https://docs.rs/tokio/latest/tokio/sync/mpsc/index.html "mod tokio::sync::mpsc"), [`watch`](https://docs.rs/tokio/latest/tokio/sync/watch/index.html "mod tokio::sync::watch"), and [`broadcast`](https://docs.rs/tokio/latest/tokio/sync/broadcast/index.html "mod tokio::sync::broadcast")), for sending values between tasks,
*   a non-blocking [`Mutex`](https://docs.rs/tokio/latest/tokio/sync/struct.Mutex.html "struct tokio::sync::Mutex"), for controlling access to a shared, mutable value,
*   an asynchronous [`Barrier`](https://docs.rs/tokio/latest/tokio/sync/struct.Barrier.html "struct tokio::sync::Barrier") type, for multiple tasks to synchronize before beginning a computation.

The `tokio::sync` module is present only when the “sync” feature flag is enabled.

The [`tokio::time`](https://docs.rs/tokio/latest/tokio/time/index.html "mod tokio::time") module provides utilities for tracking time and scheduling work. This includes functions for setting [timeouts](https://docs.rs/tokio/latest/tokio/time/fn.timeout.html "fn tokio::time::timeout") for tasks, [sleeping](https://docs.rs/tokio/latest/tokio/time/fn.sleep.html "fn tokio::time::sleep") work to run in the future, or [repeating an operation at an interval](https://docs.rs/tokio/latest/tokio/time/fn.interval.html "fn tokio::time::interval").

In order to use `tokio::time`, the “time” feature flag must be enabled.

Finally, Tokio provides a _runtime_ for executing asynchronous tasks. Most applications can use the [`#[tokio::main]`](https://docs.rs/tokio/latest/tokio/attr.main.html) macro to run their code on the Tokio runtime. However, this macro provides only basic configuration options. As an alternative, the [`tokio::runtime`](https://docs.rs/tokio/latest/tokio/runtime/index.html "mod tokio::runtime") module provides more powerful APIs for configuring and managing runtimes. You should use that module if the `#[tokio::main]` macro doesn’t provide the functionality you need.

Using the runtime requires the “rt” or “rt-multi-thread” feature flags, to enable the current-thread [single-threaded scheduler](https://docs.rs/tokio/latest/tokio/runtime/index.html#current-thread-scheduler) and the [multi-thread scheduler](https://docs.rs/tokio/latest/tokio/runtime/index.html#multi-thread-scheduler), respectively. See the [`runtime` module documentation](https://docs.rs/tokio/latest/tokio/runtime/index.html#runtime-scheduler) for details. In addition, the “macros” feature flag enables the `#[tokio::main]` and `#[tokio::test]` attributes.

### [§](https://docs.rs/tokio#cpu-bound-tasks-and-blocking-code)CPU-bound tasks and blocking code

Tokio is able to concurrently run many tasks on a few threads by repeatedly swapping the currently running task on each thread. However, this kind of swapping can only happen at `.await` points, so code that spends a long time without reaching an `.await` will prevent other tasks from running. To combat this, Tokio provides two kinds of threads: Core threads and blocking threads.

The core threads are where all asynchronous code runs, and Tokio will by default spawn one for each CPU core. You can use the environment variable `TOKIO_WORKER_THREADS` to override the default value.

The blocking threads are spawned on demand, can be used to run blocking code that would otherwise block other tasks from running and are kept alive when not used for a certain amount of time which can be configured with [`thread_keep_alive`](https://docs.rs/tokio/latest/tokio/runtime/struct.Builder.html#method.thread_keep_alive "method tokio::runtime::Builder::thread_keep_alive"). Since it is not possible for Tokio to swap out blocking tasks, like it can do with asynchronous code, the upper limit 