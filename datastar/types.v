module datastar

import json2

pub type Jsonifiable = json2.Any

pub interface Flusher {
mut:
	flush() !
}

@[params]
pub struct SSEOptions {
pub:
	write_headers bool = true
	keepalive     bool
	headers       map[string]string
	flusher       ?Flusher
}

@[params]
pub struct SSEEventOptions {
pub:
	event_id       string
	retry_duration int
}
