module main

import datastar_veb
import veb

pub struct App {
mut:
	counter int
}

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
	<h1>Patch elements</h1>
	<div id="counter">${app.counter}</div>
	<button data-on:click="@post(\'/increment\')">Increment</button>
</body>
</html>')
}

@['/increment'; post]
pub fn (mut app App) increment(mut ctx Context) veb.Result {
	mut sse := datastar_veb.start_sse(mut ctx.Context) or {
		eprintln('failed to start SSE: ${err}')
		return veb.no_result()
	}
	app.counter++
	sse.patch_elements('<div id="counter">${app.counter}</div>',
		selector: '#counter'
		mode:     .outer
	) or {}
	sse.patch_signals_value({
		'counter': app.counter
	}) or {}
	datastar_veb.close_sse(mut ctx.Context, mut sse) or {}
	return veb.no_result()
}

fn main() {
	mut app := &App{}
	veb.run[App, Context](mut app, 8080)
}
