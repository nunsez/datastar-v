module datastar

import json2
import strings

// build_event renders one Server-Sent Event in wire format.
// The result can be written either to an open SSE stream or to a regular
// HTTP response body.
pub fn build_event(event_type EventType, data_lines []string, options SSEEventOptions) string {
	mut sb := strings.new_builder(256)
	sb.write_string('event: ${event_type.as_str()}\n')
	if options.event_id != '' {
		sb.write_string('id: ${options.event_id}\n')
	}
	if options.retry_duration > 0 && options.retry_duration != default_sse_retry_duration_ms {
		sb.write_string('retry: ${options.retry_duration}\n')
	}
	for line in data_lines {
		sb.write_string('data: ${line}\n')
	}
	sb.write_string('\n')
	return sb.str()
}

pub fn patch_elements_data(elements string, options PatchElementsOptions) []string {
	mut data_lines := []string{}
	if options.selector != '' {
		data_lines << '${dataline_selector} ${options.selector}'
	}
	if options.mode != .outer {
		data_lines << '${dataline_mode} ${options.mode.str()}'
	}
	if options.namespace != .html {
		data_lines << '${dataline_namespace} ${options.namespace.str()}'
	}
	if options.use_view_transition {
		data_lines << '${dataline_use_view_transition} true'
		if options.view_transition_selector != '' {
			data_lines << '${dataline_view_transition_selector} ${options.view_transition_selector}'
		}
	}
	if elements != '' {
		for line in elements.split_into_lines() {
			data_lines << '${dataline_elements} ${line}'
		}
	}
	return data_lines
}

pub fn patch_signals_data(signals string, options PatchSignalsOptions) []string {
	mut data_lines := []string{}
	if options.only_if_missing {
		data_lines << '${dataline_only_if_missing} true'
	}
	for line in signals.split_into_lines() {
		data_lines << '${dataline_signals} ${line}'
	}
	return data_lines
}

pub fn build_patch_elements(elements string, options PatchElementsOptions) !string {
	if elements == '' && options.selector == '' {
		return error('patch_elements: elements or selector is required')
	}
	if elements == '' && options.mode != .remove {
		return error('patch_elements: elements must not be empty unless mode is remove')
	}
	return build_event(.patch_elements, patch_elements_data(elements, options),
		event_id:       options.event_id
		retry_duration: options.retry_duration
	)
}

pub fn build_patch_signals(signals string, options PatchSignalsOptions) !string {
	if signals == '' {
		return error('patch_signals: signals is required')
	}
	return build_event(.patch_signals, patch_signals_data(signals, options),
		event_id:       options.event_id
		retry_duration: options.retry_duration
	)
}

pub fn build_patch_signals_value[T](signals T, options PatchSignalsOptions) !string {
	return build_patch_signals(json2.encode(signals), options)
}
