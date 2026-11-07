module datastar_veb

import datastar
import net.http
import strings
import veb

struct TestWriter {
mut:
	buf strings.Builder
}

fn (mut w TestWriter) write(data []u8) !int {
	return w.buf.write(data)
}

struct TestSignals {
	name string
}

fn test_start_sse_requires_connection() ! {
	mut ctx := veb.Context{}
	start_sse(mut ctx) or {
		assert err.msg().contains('requires a direct TCP connection')
		return
	}
	assert false
}

fn test_close_sse_without_connection() ! {
	mut ctx := veb.Context{}
	mut writer := &TestWriter{}
	mut sse := datastar.new_sse(mut writer, write_headers: false)!
	close_sse(mut ctx, mut sse)!
	assert sse.is_closed()
}

fn test_read_signals_from_context() ! {
	ctx := veb.Context{
		req: http.Request{
			method: .post
			data:   '{"name":"veb"}'
		}
	}
	signals := read_signals[TestSignals](&ctx)!
	assert signals.name == 'veb'
}

fn test_send_sse_event() ! {
	mut ctx := veb.Context{}
	send_sse_event(mut ctx, .patch_signals, ['signals {"count":1}'],
		event_id:       'event-1'
		retry_duration: 2500
	)!
	assert ctx.res.body == 'event: datastar-patch-signals\nid: event-1\nretry: 2500\ndata: signals {"count":1}\n\n'
	assert ctx.res.header.get(.content_type)? == 'text/event-stream'
	assert ctx.res.header.get(.cache_control)? == 'no-cache'
	assert ctx.res.header.get(.connection)? == 'keep-alive'
}

fn test_patch_elements() ! {
	mut ctx := veb.Context{}
	patch_elements(mut ctx, '<div id="count">1</div>', selector: '#count')!
	assert ctx.res.body == 'event: datastar-patch-elements\ndata: selector #count\ndata: elements <div id="count">1</div>\n\n'
}

fn test_patch_signals() ! {
	mut ctx := veb.Context{}
	patch_signals(mut ctx, '{"count":1}', only_if_missing: true)!
	assert ctx.res.body == 'event: datastar-patch-signals\ndata: onlyIfMissing true\ndata: signals {"count":1}\n\n'
}

fn test_patch_signals_value() ! {
	mut ctx := veb.Context{}
	patch_signals_value(mut ctx, {
		'count': 1
	})!
	assert ctx.res.body == 'event: datastar-patch-signals\ndata: signals {"count":1}\n\n'
}

fn test_execute_script() ! {
	mut ctx := veb.Context{}
	execute_script(mut ctx, 'alert(1)')!
	assert ctx.res.body == 'event: datastar-patch-elements\ndata: selector body\ndata: mode append\ndata: elements <script data-effect="el.remove()">alert(1)</script>\n\n'
	assert ctx.res.header.get(.content_type)? == 'text/event-stream'
}

fn test_execute_script_validation() ! {
	mut ctx := veb.Context{}
	execute_script(mut ctx, '') or {
		assert err.msg().contains('script is required')
		assert ctx.res.body == ''
		return
	}
	assert false
}

fn test_console_log() ! {
	mut ctx := veb.Context{}
	console_log(mut ctx, 'hello')!
	assert ctx.res.body.contains('console.log("hello")')
}

fn test_redirect() ! {
	mut ctx := veb.Context{}
	redirect(mut ctx, '/next')!
	assert ctx.res.body.contains('setTimeout(() => window.location.href = "/next")')
}

fn test_replace_url() ! {
	mut ctx := veb.Context{}
	replace_url(mut ctx, '/next')!
	assert ctx.res.body.contains('window.history.replaceState({}, "", "/next")')
}
