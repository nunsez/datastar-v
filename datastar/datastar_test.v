module datastar

import net.http
import net.urllib
import strings

struct MemoryWriter {
mut:
	buf strings.Builder
}

fn (mut w MemoryWriter) write(data []u8) !int {
	return w.buf.write(data)
}

fn (mut w MemoryWriter) flush() ! {}

fn (mut w MemoryWriter) str() string {
	return w.buf.str()
}

fn new_test_sse() !(&MemoryWriter, &ServerSentEventGenerator) {
	mut writer := &MemoryWriter{}
	mut sse := new_sse(mut writer, write_headers: false)!
	return writer, sse
}

fn test_sse_frame() ! {
	mut writer, mut sse := new_test_sse()!
	sse.send(.patch_elements, ['selector #x', 'elements <div>x</div>'],
		event_id:       '1'
		retry_duration: 2500
	)!
	output := writer.str()
	assert output == 'event: datastar-patch-elements\nid: 1\nretry: 2500\ndata: selector #x\ndata: elements <div>x</div>\n\n'
}

fn test_sse_default_retry_is_omitted() ! {
	mut writer, mut sse := new_test_sse()!
	sse.send(.patch_signals, ['signals {}'],
		retry_duration: default_sse_retry_duration_ms
	)!
	output := writer.str()
	assert !output.contains('retry:')
}

fn test_build_event() {
	output := build_event(.patch_signals, ['signals {"count":1}'],
		event_id:       'event-1'
		retry_duration: 2500
	)
	assert output == 'event: datastar-patch-signals\nid: event-1\nretry: 2500\ndata: signals {"count":1}\n\n'
}

fn test_build_event_uses_event_type() {
	assert build_event(.patch_elements, []) == 'event: datastar-patch-elements\n\n'
	assert build_event(.patch_signals, []) == 'event: datastar-patch-signals\n\n'
}

fn test_patch_elements_data() {
	data_lines := patch_elements_data('<div>x</div>',
		selector:  '#x'
		mode:      .append
		namespace: .svg
	)
	assert data_lines == ['selector #x', 'mode append', 'namespace svg', 'elements <div>x</div>']
}

fn test_patch_signals_data() {
	data_lines := patch_signals_data('{"count":1}', only_if_missing: true)
	assert data_lines == ['onlyIfMissing true', 'signals {"count":1}']
}

fn test_build_patch_elements() ! {
	event := build_patch_elements('<div>x</div>',
		selector:       '#x'
		event_id:       'event-1'
		retry_duration: 2500
	)!
	assert event == 'event: datastar-patch-elements\nid: event-1\nretry: 2500\ndata: selector #x\ndata: elements <div>x</div>\n\n'
}

fn test_build_patch_signals() ! {
	event := build_patch_signals('{"count":1}', only_if_missing: true)!
	assert event == 'event: datastar-patch-signals\ndata: onlyIfMissing true\ndata: signals {"count":1}\n\n'
}

fn test_build_patch_signals_value() ! {
	event := build_patch_signals_value({
		'count': 1
	})!
	assert event == 'event: datastar-patch-signals\ndata: signals {"count":1}\n\n'
}

fn test_build_patch_elements_validation() ! {
	build_patch_elements('') or {
		assert err.msg().contains('elements or selector')
		return
	}
	assert false
}

fn test_sse_headers() ! {
	mut writer := &MemoryWriter{}
	mut sse := new_sse(mut writer,
		headers: {
			'X-Test': 'yes'
		}
	)!
	output := writer.str()
	assert output.starts_with('HTTP/1.1 200 OK\r\n')
	assert output.contains('Cache-Control: no-cache\r\n')
	assert output.contains('Connection: keep-alive\r\n')
	assert output.contains('Content-Type: text/event-stream\r\n')
	assert output.contains('X-Accel-Buffering: no\r\n')
	assert output.contains('X-Test: yes\r\n')
	assert output.ends_with('\r\n\r\n')
	sse.close()!
}

fn test_sse_headers_override() ! {
	mut writer := &MemoryWriter{}
	mut sse := new_sse(mut writer,
		headers: {
			'Content-Type': 'text/event-stream; charset=utf-8'
		}
	)!
	output := writer.str()
	assert output.count('Content-Type:') == 1
	assert output.contains('Content-Type: text/event-stream; charset=utf-8\r\n')
	sse.close()!
}

fn test_sse_keepalive() ! {
	mut writer, mut sse := new_test_sse()!
	sse.send_keepalive()!
	output := writer.str()
	assert output == ': keepalive\n\n'
}

fn test_sse_close() ! {
	mut writer, mut sse := new_test_sse()!
	sse.close()!
	assert sse.is_closed()
	sse.send(.patch_signals, ['signals {}']) or {
		assert err.msg() == 'SSE stream is closed'
		return
	}
	assert false
}

fn test_patch_elements_default() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_elements('<div id="x">hi</div>')!
	output := writer.str()
	assert output == 'event: datastar-patch-elements\ndata: elements <div id="x">hi</div>\n\n'
}

fn test_patch_elements_all_options() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_elements('<circle id="dot" />',
		event_id:                 'elements-1'
		retry_duration:           2000
		selector:                 '#vis'
		mode:                     .append
		namespace:                .svg
		use_view_transition:      true
		view_transition_selector: '#main'
	)!
	output := writer.str()
	assert output == 'event: datastar-patch-elements\nid: elements-1\nretry: 2000\ndata: selector #vis\ndata: mode append\ndata: namespace svg\ndata: useViewTransition true\ndata: viewTransitionSelector #main\ndata: elements <circle id="dot" />\n\n'
}

fn test_patch_elements_multiline() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_elements('<div>\n<span>hi</span>\n</div>')!
	output := writer.str()
	assert output.contains('data: elements <div>\ndata: elements <span>hi</span>\ndata: elements </div>')
}

fn test_remove_elements() ! {
	mut writer, mut sse := new_test_sse()!
	sse.remove_elements('#feed, #otherid')!
	output := writer.str()
	assert output == 'event: datastar-patch-elements\ndata: selector #feed, #otherid\ndata: mode remove\n\n'
}

fn test_patch_elements_validation() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_elements('') or {
		assert err.msg().contains('elements or selector')
		assert writer.str() == ''
		return
	}
	assert false
}

fn test_patch_elements_remove_requires_selector_or_elements() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_elements('', mode: .remove) or {
		assert err.msg().contains('elements or selector')
		assert writer.str() == ''
		return
	}
	assert false
}

fn test_patch_signals() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_signals('{"foo":1}', only_if_missing: true)!
	output := writer.str()
	assert output == 'event: datastar-patch-signals\ndata: onlyIfMissing true\ndata: signals {"foo":1}\n\n'
}

fn test_patch_signals_value() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_signals_value({
		'foo': 'bar'
	})!
	output := writer.str()
	assert output == 'event: datastar-patch-signals\ndata: signals {"foo":"bar"}\n\n'
}

fn test_patch_signals_multiline() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_signals('{"foo":1,\n"bar":2}')!
	output := writer.str()
	assert output.contains('data: signals {"foo":1,\ndata: signals "bar":2}')
}

fn test_remove_signals() ! {
	mut writer, mut sse := new_test_sse()!
	sse.remove_signals(['foo', 'bar'])!
	output := writer.str()
	assert output == 'event: datastar-patch-signals\ndata: signals {"foo":null,"bar":null}\n\n'
}

fn test_remove_signal() ! {
	mut writer, mut sse := new_test_sse()!
	sse.remove_signal('foo')!
	output := writer.str()
	assert output == 'event: datastar-patch-signals\ndata: signals {"foo":null}\n\n'
}

fn test_execute_script_auto_remove() ! {
	mut writer, mut sse := new_test_sse()!
	sse.execute_script('alert(1)')!
	output := writer.str()
	assert output.contains('data: selector body')
	assert output.contains('data: mode append')
	assert output.contains('<script data-effect="el.remove()">alert(1)</script>')
}

fn test_execute_script_attributes() ! {
	mut writer, mut sse := new_test_sse()!
	sse.execute_script('run()', auto_remove: false, raw_attributes: ['type="module"'])!
	output := writer.str()
	assert output.contains('<script type="module">run()</script>')
}

fn test_console_log() ! {
	mut writer, mut sse := new_test_sse()!
	sse.console_log('hello "world"')!
	output := writer.str()
	assert output.contains('console.log("hello \\"world\\"")')
}

fn test_console_error() ! {
	mut writer, mut sse := new_test_sse()!
	sse.console_error('boom')!
	output := writer.str()
	assert output.contains('console.error("boom")')
}

fn test_redirect() ! {
	mut writer, mut sse := new_test_sse()!
	sse.redirect('/next')!
	output := writer.str()
	assert output.contains('setTimeout(() => window.location.href = "/next")')
}

fn test_replace_url() ! {
	mut writer, mut sse := new_test_sse()!
	sse.replace_url('/next')!
	output := writer.str()
	assert output.contains('window.history.replaceState({}, "", "/next")')
}

fn test_prefetch() ! {
	mut writer, mut sse := new_test_sse()!
	sse.prefetch(['/a', '/b'])!
	output := writer.str()
	assert output.contains('type="speculationrules"')
	assert output.contains('"prefetch"')
	assert output.contains('"urls":["/a","/b"]')
}

fn test_dispatch_custom_event() ! {
	mut writer, mut sse := new_test_sse()!
	sse.dispatch_custom_event('ping', {
		'x': 1
	}, selector: '#target')!
	output := writer.str()
	assert output.contains('new CustomEvent("ping"')
	assert output.contains('detail: {"x":1}')
	assert output.contains('document.querySelectorAll("#target")')
}

struct TestSignals {
	foo string
	n   int
}

fn test_read_signals_get() ! {
	json := urllib.query_escape('{"foo":"bar","n":3}')
	req := http.Request{
		method: .get
		url:    '/?${datastar_query_key}=${json}'
	}
	signals := read_signals[TestSignals](&req)!
	assert signals.foo == 'bar'
	assert signals.n == 3
}

fn test_read_signals_delete() ! {
	json := urllib.query_escape('{"foo":"baz"}')
	req := http.Request{
		method: .delete
		url:    '/?${datastar_query_key}=${json}'
	}
	signals := read_signals[TestSignals](&req)!
	assert signals.foo == 'baz'
}

fn test_read_signals_post() ! {
	req := http.Request{
		method: .post
		data:   '{"foo":"post","n":7}'
	}
	signals := read_signals[TestSignals](&req)!
	assert signals.foo == 'post'
	assert signals.n == 7
}

fn test_read_signals_empty() ! {
	req := http.Request{
		method: .get
		url:    '/plain'
	}
	signals := read_signals[TestSignals](&req)!
	assert signals.foo == ''
	assert signals.n == 0
}

struct FailingWriter {}

fn (mut w FailingWriter) write(_ []u8) !int {
	return error('write failed')
}

struct ToggleFlusher {
mut:
	fail bool
}

fn (mut f ToggleFlusher) flush() ! {
	if f.fail {
		return error('flush failed')
	}
}

fn test_sse_is_closed_initial_and_idempotent_close() ! {
	mut writer, mut sse := new_test_sse()!
	assert !sse.is_closed()
	sse.close()!
	sse.close()!
	assert sse.is_closed()
}

fn test_sse_send_keepalive_after_close() ! {
	mut writer, mut sse := new_test_sse()!
	sse.close()!
	sse.send_keepalive() or {
		assert err.msg() == 'SSE stream is closed'
		return
	}
	assert false
}

fn test_write_event() ! {
	mut writer, mut sse := new_test_sse()!
	sse.write_event('event: custom\ndata: hello\n\n')!
	assert writer.str() == 'event: custom\ndata: hello\n\n'
}

fn test_sse_send_empty_data_lines() ! {
	mut writer, mut sse := new_test_sse()!
	sse.send(.patch_signals, [])!
	output := writer.str()
	assert output == 'event: datastar-patch-signals\n\n'
}

fn test_sse_send_negative_retry_omitted() ! {
	mut writer, mut sse := new_test_sse()!
	sse.send(.patch_signals, ['signals {}'], retry_duration: -1)!
	output := writer.str()
	assert !output.contains('retry:')
}

fn test_new_sse_flush_error() ! {
	mut writer := &MemoryWriter{}
	mut flusher := &ToggleFlusher{
		fail: true
	}
	new_sse(mut writer, flusher: flusher) or {
		assert err.msg().contains('flush failed')
		return
	}
	assert false
}

fn test_send_write_error_closes_stream() ! {
	mut writer := &FailingWriter{}
	mut sse := new_sse(mut writer, write_headers: false)!
	sse.send(.patch_signals, ['signals {}']) or {
		assert err.msg().contains('failed to write')
		assert sse.is_closed()
		return
	}
	assert false
}

fn test_send_flush_error_closes_stream() ! {
	mut writer := &MemoryWriter{}
	mut flusher := &ToggleFlusher{}
	mut sse := new_sse(mut writer, flusher: flusher)!
	flusher.fail = true
	sse.send(.patch_signals, ['signals {}']) or {
		assert err.msg().contains('failed to flush')
		assert sse.is_closed()
		return
	}
	assert false
}

fn test_keepalive_write_error_closes_stream() ! {
	mut writer := &FailingWriter{}
	mut sse := new_sse(mut writer, write_headers: false)!
	sse.send_keepalive() or {
		assert err.msg().contains('failed to write')
		assert sse.is_closed()
		return
	}
	assert false
}

fn test_close_flush_error() ! {
	mut writer := &MemoryWriter{}
	mut flusher := &ToggleFlusher{}
	mut sse := new_sse(mut writer, flusher: flusher)!
	flusher.fail = true
	sse.close() or {
		assert err.msg().contains('flush failed')
		return
	}
	assert false
}

fn test_remove_elements_validation() ! {
	mut writer, mut sse := new_test_sse()!
	sse.remove_elements('') or {
		assert err.msg().contains('selector is required')
		assert writer.str() == ''
		return
	}
	assert false
}

fn test_patch_elements_empty_with_selector_validation() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_elements('', selector: '#x') or {
		assert err.msg().contains('elements must not be empty')
		assert writer.str() == ''
		return
	}
	assert false
}

fn test_patch_signals_validation() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_signals('') or {
		assert err.msg().contains('signals is required')
		assert writer.str() == ''
		return
	}
	assert false
}

fn test_remove_signals_validation() ! {
	mut writer, mut sse := new_test_sse()!
	sse.remove_signals([]string{}) or {
		assert err.msg().contains('at least one key is required')
		assert writer.str() == ''
		return
	}
	assert false
}

fn test_execute_script_validation() ! {
	mut writer, mut sse := new_test_sse()!
	sse.execute_script('') or {
		assert err.msg().contains('script is required')
		assert writer.str() == ''
		return
	}
	assert false
}

fn test_prefetch_validation() ! {
	mut writer, mut sse := new_test_sse()!
	sse.prefetch([]string{}) or {
		assert err.msg().contains('at least one URL is required')
		assert writer.str() == ''
		return
	}
	assert false
}

fn test_dispatch_custom_event_validation() ! {
	mut writer, mut sse := new_test_sse()!
	sse.dispatch_custom_event('', map[string]string{}) or {
		assert err.msg().contains('event name is required')
		assert writer.str() == ''
		return
	}
	assert false
}

fn test_patch_elements_mode_and_mathml() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_elements('<math></math>', mode: .replace, namespace: .mathml)!
	output := writer.str()
	assert output.contains('data: mode replace')
	assert output.contains('data: namespace mathml')
}

fn test_patch_elements_view_transition_selector_without_transition() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_elements('<div>x</div>', view_transition_selector: '#main')!
	output := writer.str()
	assert !output.contains('viewTransitionSelector')
}

fn test_patch_elements_view_transition_without_selector() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_elements('<div>x</div>', use_view_transition: true)!
	output := writer.str()
	assert output.contains('data: useViewTransition true')
	assert !output.contains('viewTransitionSelector')
}

fn test_patch_elements_remove_mode_with_elements() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_elements('<div>x</div>', mode: .remove)!
	output := writer.str()
	assert output.contains('data: mode remove')
	assert output.contains('data: elements <div>x</div>')
}

fn test_patch_elements_crlf_and_trailing_newline() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_elements('<div>\r\n<span>x</span>\r\n</div>\r\n')!
	output := writer.str()
	assert output.contains('data: elements <div>\ndata: elements <span>x</span>\ndata: elements </div>')
}

fn test_execute_script_boolean_attribute() ! {
	mut writer, mut sse := new_test_sse()!
	sse.execute_script('run()',
		auto_remove: false
		attributes:  {
			'defer': ''
		}
	)!
	output := writer.str()
	assert output.contains('<script defer>run()</script>')
}

fn test_execute_script_map_attribute() ! {
	mut writer, mut sse := new_test_sse()!
	sse.execute_script('run()',
		auto_remove: false
		attributes:  {
			'type': 'module'
		}
	)!
	output := writer.str()
	assert output.contains('<script type="module">run()</script>')
}

fn test_execute_script_raw_and_map_attributes() ! {
	mut writer, mut sse := new_test_sse()!
	sse.execute_script('run()',
		auto_remove:    false
		raw_attributes: ['type="module"']
		attributes:     {
			'defer': ''
		}
	)!
	output := writer.str()
	assert output.contains('<script type="module" defer>run()</script>')
}

fn test_execute_script_without_auto_remove() ! {
	mut writer, mut sse := new_test_sse()!
	sse.execute_script('run()', auto_remove: false)!
	output := writer.str()
	assert output.contains('<script>run()</script>')
	assert !output.contains('data-effect')
}

fn test_execute_script_event_id_and_retry() ! {
	mut writer, mut sse := new_test_sse()!
	sse.execute_script('run()', event_id: 'script-1', retry_duration: 2000)!
	output := writer.str()
	assert output.contains('id: script-1')
	assert output.contains('retry: 2000')
}

fn test_prefetch_custom_attributes() ! {
	mut writer, mut sse := new_test_sse()!
	sse.prefetch(['/a'],
		attributes:     {
			'nonce': 'abc'
		}
		raw_attributes: ['data-test="1"']
	)!
	output := writer.str()
	assert output.contains('type="speculationrules"')
	assert output.contains('nonce="abc"')
	assert output.contains('data-test="1"')
	assert !output.contains('data-effect')
}

fn test_dispatch_custom_event_default_document() ! {
	mut writer, mut sse := new_test_sse()!
	sse.dispatch_custom_event('ping', {
		'x': 1
	})!
	output := writer.str()
	assert output.contains('const elements = [document];')
	assert output.contains('new CustomEvent("ping"')
}

fn test_dispatch_custom_event_flags_false() ! {
	mut writer, mut sse := new_test_sse()!
	sse.dispatch_custom_event('ping', map[string]string{},
		bubbles:    false
		cancelable: false
		composed:   false
	)!
	output := writer.str()
	assert output.contains('bubbles: false')
	assert output.contains('cancelable: false')
	assert output.contains('composed: false')
}

fn test_dispatch_custom_event_string_detail() ! {
	mut writer, mut sse := new_test_sse()!
	sse.dispatch_custom_event('ping', 'hello')!
	output := writer.str()
	assert output.contains('detail: "hello"')
}

fn test_dispatch_custom_event_array_detail() ! {
	mut writer, mut sse := new_test_sse()!
	sse.dispatch_custom_event('ping', [1, 2])!
	output := writer.str()
	assert output.contains('detail: [1,2]')
}

fn test_dispatch_custom_event_selector_with_quote() ! {
	mut writer, mut sse := new_test_sse()!
	sse.dispatch_custom_event('ping', map[string]string{}, selector: '#a"b')!
	output := writer.str()
	assert output.contains(r'document.querySelectorAll("#a\"b")')
}

fn test_patch_signals_value_struct() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_signals_value(TestSignals{
		foo: 'x'
		n:   3
	})!
	output := writer.str()
	assert output.contains('data: signals {"foo":"x","n":3}')
}

fn test_patch_signals_value_array() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_signals_value([1, 2])!
	output := writer.str()
	assert output.contains('data: signals [1,2]')
}

fn test_patch_signals_value_bool() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_signals_value(true)!
	output := writer.str()
	assert output.contains('data: signals true')
}

fn test_patch_signals_value_nested() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_signals_value({
		'outer': map[string]int{
			'inner': 1
		}
	})!
	output := writer.str()
	assert output.contains('data: signals {"outer":{"inner":1}}')
}

fn test_patch_signals_value_escaping() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_signals_value({
		'x': 'a"b'
	})!
	output := writer.str()
	assert output.contains(r'data: signals {"x":"a\"b"}')
}

fn test_remove_signals_escaping() ! {
	mut writer, mut sse := new_test_sse()!
	sse.remove_signals(['a b', 'c"d'])!
	output := writer.str()
	assert output.contains(r'data: signals {"a b":null,"c\"d":null}')
}

fn test_remove_signals_only_if_missing() ! {
	mut writer, mut sse := new_test_sse()!
	sse.remove_signals(['foo'], only_if_missing: true)!
	output := writer.str()
	assert output.contains('data: onlyIfMissing true')
	assert output.contains('data: signals {"foo":null}')
}

fn test_read_signals_invalid_json() ! {
	req := http.Request{
		method: .post
		data:   'not json'
	}
	read_signals[TestSignals](&req) or {
		assert err.msg() != ''
		return
	}
	assert false
}

fn test_read_signals_put() ! {
	req := http.Request{
		method: .put
		data:   '{"foo":"put","n":2}'
	}
	signals := read_signals[TestSignals](&req)!
	assert signals.foo == 'put'
	assert signals.n == 2
}

fn test_read_signals_get_with_other_query_params() ! {
	json := urllib.query_escape('{"foo":"bar"}')
	req := http.Request{
		method: .get
		url:    '/?x=1&${datastar_query_key}=${json}&y=2'
	}
	signals := read_signals[TestSignals](&req)!
	assert signals.foo == 'bar'
}

fn test_read_signals_get_full_url() ! {
	json := urllib.query_escape('{"foo":"full"}')
	req := http.Request{
		method: .get
		url:    'http://localhost/path?${datastar_query_key}=${json}'
	}
	signals := read_signals[TestSignals](&req)!
	assert signals.foo == 'full'
}

fn test_read_signals_post_empty_body() ! {
	req := http.Request{
		method: .post
		data:   ''
	}
	signals := read_signals[TestSignals](&req)!
	assert signals.foo == ''
	assert signals.n == 0
}

fn test_patch_elements_all_modes() ! {
	for mode in [ElementPatchMode.outer, .inner, .remove, .replace, .prepend, .append, .before,
		.after] {
		mut writer, mut sse := new_test_sse()!
		sse.patch_elements('<div>x</div>', mode: mode)!
		output := writer.str()
		if mode == .outer {
			assert !output.contains('data: mode')
		} else {
			assert output.contains('data: mode ${mode.str()}')
		}
	}
}

fn test_patch_elements_all_namespaces() ! {
	for namespace in [Namespace.html, .svg, .mathml] {
		mut writer, mut sse := new_test_sse()!
		sse.patch_elements('<div>x</div>', namespace: namespace)!
		output := writer.str()
		if namespace == .html {
			assert !output.contains('data: namespace')
		} else {
			assert output.contains('data: namespace ${namespace.str()}')
		}
	}
}

fn test_remove_signals_event_id_and_retry() ! {
	mut writer, mut sse := new_test_sse()!
	sse.remove_signals(['foo'], event_id: 'signals-1', retry_duration: 2000)!
	output := writer.str()
	assert output.contains('id: signals-1')
	assert output.contains('retry: 2000')
}

fn test_dispatch_custom_event_empty_selector_uses_document() ! {
	mut writer, mut sse := new_test_sse()!
	sse.dispatch_custom_event('ping', map[string]string{}, selector: '')!
	output := writer.str()
	assert output.contains('const elements = [document];')
}

fn test_keepalive_flush_error_closes_stream() ! {
	mut writer := &MemoryWriter{}
	mut flusher := &ToggleFlusher{}
	mut sse := new_sse(mut writer, flusher: flusher)!
	flusher.fail = true
	sse.send_keepalive() or {
		assert err.msg().contains('failed to flush')
		assert sse.is_closed()
		return
	}
	assert false
}

fn test_read_signals_get_empty_url() ! {
	req := http.Request{
		method: .get
		url:    ''
	}
	signals := read_signals[TestSignals](&req)!
	assert signals.foo == ''
	assert signals.n == 0
}

fn test_remove_elements_event_id_and_retry() ! {
	mut writer, mut sse := new_test_sse()!
	sse.remove_elements('#x', event_id: 'elements-1', retry_duration: 2000)!
	output := writer.str()
	assert output.contains('id: elements-1')
	assert output.contains('retry: 2000')
}

fn test_patch_signals_event_id_and_retry() ! {
	mut writer, mut sse := new_test_sse()!
	sse.patch_signals('{}', event_id: 'signals-1', retry_duration: 2000)!
	output := writer.str()
	assert output.contains('id: signals-1')
	assert output.contains('retry: 2000')
}

fn test_prefetch_event_id_and_retry() ! {
	mut writer, mut sse := new_test_sse()!
	sse.prefetch(['/a'], event_id: 'prefetch-1', retry_duration: 2000)!
	output := writer.str()
	assert output.contains('id: prefetch-1')
	assert output.contains('retry: 2000')
}

fn test_dispatch_custom_event_event_id_and_retry() ! {
	mut writer, mut sse := new_test_sse()!
	sse.dispatch_custom_event('ping', map[string]string{},
		event_id:       'event-1'
		retry_duration: 2000
	)!
	output := writer.str()
	assert output.contains('id: event-1')
	assert output.contains('retry: 2000')
}

fn test_redirect_escapes_url() ! {
	mut writer, mut sse := new_test_sse()!
	sse.redirect('/a"b')!
	output := writer.str()
	assert output.contains(r'window.location.href = "/a\"b"')
}

fn test_replace_url_escapes_url() ! {
	mut writer, mut sse := new_test_sse()!
	sse.replace_url('/a"b')!
	output := writer.str()
	assert output.contains(r'replaceState({}, "", "/a\"b")')
}

fn test_console_log_escapes_newline() ! {
	mut writer, mut sse := new_test_sse()!
	sse.console_log('a\nb')!
	output := writer.str()
	assert output.contains(r'console.log("a\nb")')
}

fn test_read_signals_get_empty_datastar_value() ! {
	req := http.Request{
		method: .get
		url:    '/?${datastar_query_key}='
	}
	signals := read_signals[TestSignals](&req)!
	assert signals.foo == ''
	assert signals.n == 0
}
