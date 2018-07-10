import http from "k6/http";
import { group } from "k6";
import { urlbase, check_response, call_endpoint } from "../utils/common.js";
import { call_root } from "../basic/root.js";
import { retrieve_image } from "../basic/image.js";
import { retrieve_css_style } from "../basic/css_style.js";

// exercise calling the root and getting an image
export default function() {
    group("full_flow", function() {
        var res = call_root();
        check_response(res, { duration: 500, status: 200 });

        res = retrieve_css_style();
        check_response(res, { duration: 300, status: 200 });

        res = retrieve_image();
        check_response(res, { duration: 1000, status: 200 });
    });
};