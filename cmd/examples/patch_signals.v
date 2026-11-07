module main

import datastar_veb
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
<body data-signals:name="\'World\'">
	<h1>Patch signals</h1>
	<input data-bind:name />
	<button data-on:click="@post(\'/greet\')">Greet</button>
	<div data-text="$greeting"></div>
</body>
</html>')
}

@['/greet'; post]
pub fn (app &App) greet(mut ctx Context) veb.Result {
	signals := datastar_veb.read_signals[GreetingSignals](&ctx.Context) or {
		return ctx.text(err.msg())
	}
	mut sse := datastar_veb.start_sse(mut ctx.Context) or {
		eprintln('failed to start SSE: ${err}')
		return veb.no_result()
	}
	sse.patch_signals_value({
		'greeting': 'Hello, ${signals.name}!'
	}) or {}
	datastar_veb.close_sse(mut ctx.Context, mut sse) or {}
	return veb.no_result()
}

struct GreetingSignals {
	name string
}

fn main() {
	mut app := &App{}
	veb.run[App, Context](mut app, 8080)
}
