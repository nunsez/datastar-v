module datastar

import json2

@[params]
pub struct PatchSignalsOptions {
pub:
	event_id        string
	retry_duration  int
	only_if_missing bool
}

pub fn (mut sse ServerSentEventGenerator) patch_signals(signals string, options PatchSignalsOptions) ! {
	sse.write_event(build_patch_signals(signals, options)!)!
}

pub fn (mut sse ServerSentEventGenerator) patch_signals_value[T](signals T, options PatchSignalsOptions) ! {
	sse.write_event(build_patch_signals_value(signals, options)!)!
}

@[params]
pub struct RemoveSignalsOptions {
pub:
	event_id        string
	retry_duration  int
	only_if_missing bool
}

pub fn (mut sse ServerSentEventGenerator) remove_signals(keys []string, options RemoveSignalsOptions) ! {
	if keys.len == 0 {
		return error('remove_signals: at least one key is required')
	}
	mut parts := []string{cap: keys.len}
	for key in keys {
		parts << '${json2.encode(key)}:null'
	}
	return sse.patch_signals('{${parts.join(',')}}',
		event_id:        options.event_id
		retry_duration:  options.retry_duration
		only_if_missing: options.only_if_missing
	)
}

pub fn (mut sse ServerSentEventGenerator) remove_signal(key string, options RemoveSignalsOptions) ! {
	return sse.remove_signals([key], options)
}
