module datastar_veb

import datastar
import veb

pub fn send_sse_event(mut ctx veb.Context, event_type datastar.EventType, data_lines []string, options datastar.SSEEventOptions) !veb.Result {
	return send_sse_body(mut ctx, datastar.build_event(event_type, data_lines, options))
}

pub fn patch_elements(mut ctx veb.Context, elements string, options datastar.PatchElementsOptions) !veb.Result {
	return send_sse_body(mut ctx, datastar.build_patch_elements(elements, options)!)
}

pub fn patch_signals(mut ctx veb.Context, signals string, options datastar.PatchSignalsOptions) !veb.Result {
	return send_sse_body(mut ctx, datastar.build_patch_signals(signals, options)!)
}

pub fn patch_signals_value[T](mut ctx veb.Context, signals T, options datastar.PatchSignalsOptions) !veb.Result {
	return send_sse_body(mut ctx, datastar.build_patch_signals_value(signals, options)!)
}

fn send_sse_body(mut ctx veb.Context, body string) !veb.Result {
	for key, value in datastar.sse_headers {
		ctx.set_custom_header(key, value)!
	}
	return ctx.send_response_to_client(datastar.sse_content_type, body)
}

pub fn start_sse(mut ctx veb.Context) !&datastar.ServerSentEventGenerator {
	ctx.takeover_conn()
	if isnil(ctx.conn) {
		return error('datastar: veb SSE requires a direct TCP connection')
	}
	mut conn := ctx.conn
	return datastar.new_sse(mut conn) or {
		conn.close() or {}
		return error('datastar: failed to start SSE: ${err}')
	}
}

pub fn read_signals[T](ctx &veb.Context) !T {
	return datastar.read_signals[T](&ctx.req)
}

pub fn close_sse(mut ctx veb.Context, mut sse datastar.ServerSentEventGenerator) ! {
	// Only close the SSE stream, NOT the underlying connection.
	// When using takeover_conn, the fasthttp backend manages the connection lifecycle.
	return sse.close()
}
