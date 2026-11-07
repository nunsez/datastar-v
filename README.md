# datastar-v

Datastar SDK for V. Generates Server-Sent Events (SSE) for patching DOM
elements and signals, executing client-side scripts, and reading signals from
incoming requests.

## Requirements

- V 0.5.2 or newer
- Core uses only the standard library (`io`, `net.http`, `net.urllib`, `json2`, `sync`)
- The veb adapter uses `veb` from `vlib`; importing `datastar` alone does not require it

## Project layout

The repository contains two V modules:

- `datastar/` — core SDK, imported as `datastar`
- `datastar_veb/` — veb adapter, imported as `datastar_veb`

V forbids a module named `veb` from importing the standard library module of the
same name, hence the distinct adapter name.

## Core API

```v
import datastar.datastar

mut sse := datastar.new_sse(mut writer)!

sse.patch_elements('<div id="counter">1</div>', selector: '#counter', mode: .outer)!
sse.patch_signals('{"count":1}')!
sse.patch_signals_value({'count': 1})!

sse.remove_elements('#counter')!
sse.remove_signals(['temporary', 'stale'])!

sse.execute_script('console.log("hello")')!
sse.console_log('hello')!
sse.redirect('/next')!
sse.replace_url('/next')!
sse.prefetch(['/page-a', '/page-b'])!
sse.dispatch_custom_event('counter-updated', {'count': 1})!

sse.close()!
```

`new_sse` writes the SSE headers and flushes. Pass `write_headers: false` when
the transport already sent headers, for example in tests:

```v
mut sse := datastar.new_sse(mut writer, write_headers: false)!
```

## Reading signals

`read_signals` returns a decoded value. `GET` and `DELETE` requests use the
`datastar` query parameter; other methods use the request body.

```v
struct Signals {
	name string
}

signals := datastar.read_signals[Signals](req)!
```

With veb:

```v
signals := datastar_veb.read_signals[Signals](&ctx.Context)!
```

## veb adapter

```v
mut sse := datastar_veb.start_sse(mut ctx.Context)!
sse.patch_signals_value({'count': 1})!
datastar_veb.close_sse(mut ctx.Context, mut sse)!
```

If `start_sse` fails, log the error and return `veb.no_result()`: veb may
already own the connection.

## Low-level events

```v
sse.send(.patch_signals, ['signals {"count":1}'],
	event_id:       'event-1'
	retry_duration: 2500
)!

sse.send_keepalive()!
```

Events can be built as text without a live stream:

```v
event := datastar.build_patch_signals('{"count":1}')!

data_lines := datastar.patch_signals_data('{"count":1}')
custom := datastar.build_event(.patch_signals, data_lines)
```

Write the result to an open stream with `sse.write_event(event)!`. The default
retry duration is `1000` ms and is omitted when it equals the default.

## Tests and examples

```sh
v test .
v run cmd/examples/basic_sse.v
v run cmd/examples/full_example.v
```

Both commands run from the repository root; `full_example.v` demonstrates the
veb adapter.
