module datastar

import io
import strings
import sync

pub struct ServerSentEventGenerator {
mut:
	writer    io.Writer
	flusher   ?Flusher
	mu        sync.Mutex
	closed    bool
	keepalive bool
}

pub fn new_sse(mut writer io.Writer, options SSEOptions) !&ServerSentEventGenerator {
	if options.write_headers {
		write_sse_headers(mut writer, options.headers)!
	}
	mut sse := &ServerSentEventGenerator{
		writer:    writer
		flusher:   options.flusher
		keepalive: options.keepalive
	}
	sse.flush()!
	return sse
}

fn write_sse_headers(mut writer io.Writer, extra map[string]string) ! {
	mut headers := sse_headers.clone()
	for key, value in extra {
		headers[key] = value
	}
	mut sb := strings.new_builder(128)
	sb.write_string('HTTP/1.1 200 OK\r\n')
	for key, value in headers {
		sb.write_string('${key}: ${value}\r\n')
	}
	sb.write_string('\r\n')
	writer.write(sb.str().bytes())!
}

fn (mut sse ServerSentEventGenerator) flush() ! {
	if mut f := sse.flusher {
		f.flush()!
	}
}

pub fn (mut sse ServerSentEventGenerator) send(event_type EventType, data_lines []string, options SSEEventOptions) ! {
	sse.write_event(build_event(event_type, data_lines, options))!
}

// write_event writes an already formatted SSE event block to the stream.
// The event must include its terminating blank line, for example the result of
// `build_event` or `build_patch_signals`.
pub fn (mut sse ServerSentEventGenerator) write_event(event string) ! {
	sse.mu.lock()
	defer {
		sse.mu.unlock()
	}
	if sse.closed {
		return error('SSE stream is closed')
	}
	sse.writer.write(event.bytes()) or {
		sse.closed = true
		return error('failed to write SSE event: ${err}')
	}
	sse.flush() or {
		sse.closed = true
		return error('failed to flush SSE event: ${err}')
	}
}

pub fn (mut sse ServerSentEventGenerator) send_keepalive() ! {
	sse.mu.lock()
	defer {
		sse.mu.unlock()
	}
	if sse.closed {
		return error('SSE stream is closed')
	}
	sse.writer.write(': keepalive\n\n'.bytes()) or {
		sse.closed = true
		return error('failed to write SSE keepalive: ${err}')
	}
	sse.flush() or {
		sse.closed = true
		return error('failed to flush SSE keepalive: ${err}')
	}
}

pub fn (mut sse ServerSentEventGenerator) close() ! {
	sse.mu.lock()
	defer {
		sse.mu.unlock()
	}
	if sse.closed {
		return
	}
	sse.flush()!
	sse.closed = true
}

pub fn (mut sse ServerSentEventGenerator) is_closed() bool {
	sse.mu.lock()
	defer {
		sse.mu.unlock()
	}
	return sse.closed
}
