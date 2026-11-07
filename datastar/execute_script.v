module datastar

import json2
import strings

@[params]
pub struct ExecuteScriptOptions {
pub:
	event_id       string
	retry_duration int
	auto_remove    bool = true
	attributes     map[string]string
	raw_attributes []string
}

fn build_script_tag(script string, options ExecuteScriptOptions) string {
	mut attrs := []string{cap: options.attributes.len + options.raw_attributes.len + 1}
	attrs << options.raw_attributes
	for key, value in options.attributes {
		if value == '' {
			attrs << key
		} else {
			attrs << '${key}="${value}"'
		}
	}
	if options.auto_remove {
		attrs << 'data-effect="el.remove()"'
	}
	mut tag := strings.new_builder(64 + script.len)
	tag.write_string('<script')
	for attr in attrs {
		tag.write_string(' ')
		tag.write_string(attr)
	}
	tag.write_string('>')
	tag.write_string(script)
	tag.write_string('</script>')
	return tag.str()
}

pub fn build_execute_script(script string, options ExecuteScriptOptions) !string {
	if script == '' {
		return error('execute_script: script is required')
	}
	tag := build_script_tag(script, options)
	return build_patch_elements(tag,
		selector:       'body'
		mode:           .append
		event_id:       options.event_id
		retry_duration: options.retry_duration
	)
}

pub fn (mut sse ServerSentEventGenerator) execute_script(script string, options ExecuteScriptOptions) ! {
	sse.write_event(build_execute_script(script, options)!)!
}

pub fn build_console_log(msg string, options ExecuteScriptOptions) !string {
	return build_execute_script('console.log(${json2.encode(msg)})', options)
}

pub fn (mut sse ServerSentEventGenerator) console_log(msg string, options ExecuteScriptOptions) ! {
	sse.write_event(build_console_log(msg, options)!)!
}

pub fn (mut sse ServerSentEventGenerator) console_error(msg string, options ExecuteScriptOptions) ! {
	return sse.execute_script('console.error(${json2.encode(msg)})', options)
}

pub fn build_redirect(url string, options ExecuteScriptOptions) !string {
	return build_execute_script('setTimeout(() => window.location.href = ${json2.encode(url)})',
		options)
}

pub fn (mut sse ServerSentEventGenerator) redirect(url string, options ExecuteScriptOptions) ! {
	sse.write_event(build_redirect(url, options)!)!
}

pub fn build_replace_url(url string, options ExecuteScriptOptions) !string {
	return build_execute_script('window.history.replaceState({}, "", ${json2.encode(url)})',
		options)
}

pub fn (mut sse ServerSentEventGenerator) replace_url(url string, options ExecuteScriptOptions) ! {
	sse.write_event(build_replace_url(url, options)!)!
}

struct PrefetchRule {
	source string
	urls   []string
}

struct SpeculationRules {
	prefetch []PrefetchRule
}

pub fn (mut sse ServerSentEventGenerator) prefetch(urls []string, options ExecuteScriptOptions) ! {
	if urls.len == 0 {
		return error('prefetch: at least one URL is required')
	}
	rules := SpeculationRules{
		prefetch: [PrefetchRule{ source: 'list', urls: urls }]
	}
	script := json2.encode(rules)
	mut attributes := options.attributes.clone()
	attributes['type'] = 'speculationrules'
	return sse.execute_script(script,
		event_id:       options.event_id
		retry_duration: options.retry_duration
		auto_remove:    false
		attributes:     attributes
		raw_attributes: options.raw_attributes
	)
}

@[params]
pub struct DispatchCustomEventOptions {
pub:
	event_id       string
	retry_duration int
	selector       string = 'document'
	bubbles        bool   = true
	cancelable     bool   = true
	composed       bool   = true
}

pub fn (mut sse ServerSentEventGenerator) dispatch_custom_event[T](event_name string, detail T, options DispatchCustomEventOptions) ! {
	if event_name == '' {
		return error('dispatch_custom_event: event name is required')
	}
	elements_js := if options.selector == '' || options.selector == 'document' {
		'[document]'
	} else {
		'document.querySelectorAll(${json2.encode(options.selector)})'
	}
	js := '
{
	const elements = ${elements_js};
	const event = new CustomEvent(${json2.encode(event_name)}, {
		bubbles: ${options.bubbles},
		cancelable: ${options.cancelable},
		composed: ${options.composed},
		detail: ${json2.encode(detail)},
	});
	elements.forEach((element) => {
		element.dispatchEvent(event);
	});
}'
	return sse.execute_script(js,
		event_id:       options.event_id
		retry_duration: options.retry_duration
	)
}
