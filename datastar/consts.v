module datastar

pub enum EventType {
	patch_elements
	patch_signals
}

pub fn (event_type EventType) as_str() string {
	return match event_type {
		.patch_elements { 'datastar-patch-elements' }
		.patch_signals { 'datastar-patch-signals' }
	}
}

pub const dataline_selector = 'selector'
pub const dataline_mode = 'mode'
pub const dataline_elements = 'elements'
pub const dataline_namespace = 'namespace'
pub const dataline_use_view_transition = 'useViewTransition'
pub const dataline_view_transition_selector = 'viewTransitionSelector'
pub const dataline_signals = 'signals'
pub const dataline_only_if_missing = 'onlyIfMissing'

pub const default_sse_retry_duration_ms = 1000
pub const default_elements_use_view_transitions = false
pub const default_patch_signals_only_if_missing = false
pub const datastar_request_header = 'Datastar-Request'
pub const datastar_query_key = 'datastar'

pub const sse_content_type = 'text/event-stream'

pub const sse_headers = {
	'Cache-Control':     'no-cache'
	'Connection':        'keep-alive'
	'Content-Type':      sse_content_type
	'X-Accel-Buffering': 'no'
}

pub enum ElementPatchMode {
	outer
	inner
	remove
	replace
	prepend
	append
	before
	after
}

pub enum Namespace {
	html
	svg
	mathml
}

pub const default_element_patch_mode = ElementPatchMode.outer
pub const default_namespace = Namespace.html
