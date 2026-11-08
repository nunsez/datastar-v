module main

import datastar_veb
import time
import veb

pub struct App {}

pub struct Context {
	veb.Context
}

@['/']
pub fn (app &App) index(mut ctx Context) veb.Result {
	return ctx.html('
<!doctype html>
<html>
<head>
	<script type="module" src="https://cdn.jsdelivr.net/gh/starfederation/datastar@1.0.1/bundles/datastar.js"></script>
</head>
<body>
	<h1>Datastar V SSE</h1>
	<div>Count: <span data-text="$count">0</span></div>
	<button data-on:click="@get(\'/events\')">Start</button>
</body>
</html>')
}

@['/events']
pub fn (app &App) events(mut ctx Context) veb.Result {
	mut sse := datastar_veb.start_sse(mut ctx.Context) or {
		eprintln('failed to start SSE: ${err}')
		return veb.no_result()
	}
	for i in 0 .. 10 {
		sse.patch_signals_value({
			'count': i
		}) or { break }
		time.sleep(time.second)
	}
	datastar_veb.close_sse(mut ctx.Context, mut sse) or {}
	return veb.no_result()
}

fn main() {
	mut app := &App{}
	veb.run[App, Context](mut app, 8080)
}
