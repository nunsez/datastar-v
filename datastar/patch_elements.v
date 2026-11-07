module datastar

@[params]
pub struct PatchElementsOptions {
pub:
	event_id                 string
	retry_duration           int
	selector                 string
	mode                     ElementPatchMode = .outer
	namespace                Namespace        = .html
	use_view_transition      bool
	view_transition_selector string
}

pub fn (mut sse ServerSentEventGenerator) patch_elements(elements string, options PatchElementsOptions) ! {
	sse.write_event(build_patch_elements(elements, options)!)!
}

@[params]
pub struct RemoveElementsOptions {
pub:
	event_id       string
	retry_duration int
}

pub fn (mut sse ServerSentEventGenerator) remove_elements(selector string, options RemoveElementsOptions) ! {
	if selector == '' {
		return error('remove_elements: selector is required')
	}
	return sse.patch_elements('',
		selector:       selector
		mode:           .remove
		event_id:       options.event_id
		retry_duration: options.retry_duration
	)
}
