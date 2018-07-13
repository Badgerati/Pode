import http from "k6/http";
import { group } from "k6";
import { urlbase, check_response, call_endpoint } from "../utils/common.js";

// exported: hit the root url
export function call_root() {
    return call_endpoint(`${urlbase}`);
};

// exercise calling the root url
export default function() {
    group("root_url", function() {
        var res = call_root();
        check_response(res, { duration: 500, status: 200 });
    });
};