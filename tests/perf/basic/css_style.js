import http from "k6/http";
import { group } from "k6";
import { urlbase, check_response, call_endpoint } from "../utils/common.js";
import { call_root } from "../basic/root.js";

// exported: retrieve a css style
export function retrieve_css_style() {
    return call_endpoint(`${urlbase}/styles/simple.css`);
};

// exercise calling the root and getting a css style
export default function() {
    group("css_and_root", function() {
        var res = call_root();
        check_response(res, { duration: 500, status: 200 });

        res = retrieve_css_style();
        check_response(res, { duration: 300, status: 200 });
    });
};