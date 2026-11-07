module datastar

import json2
import net.http
import net.urllib

pub fn read_signals[T](req &http.Request) !T {
	mut json_string := ''
	if req.method == .get || req.method == .delete {
		if req.url == '' {
			return T{}
		}
		url := urllib.parse_request_uri(req.url)!
		json_string = url.query().get(datastar_query_key) or { '' }
	} else {
		json_string = req.data
	}
	if json_string == '' {
		return T{}
	}
	return json2.decode[T](json_string)!
}
