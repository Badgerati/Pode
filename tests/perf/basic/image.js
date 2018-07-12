import http from "k6/http";
import { group } from "k6";
import { urlbase, check_response, call_endpoint } from "../utils/common.js";
import { call_root } from "../basic/root.js";

// exported: retrieve an image file
export function retrieve_image() {
    return call_endpoint(`${urlbase}/Anger.jpg`);
};

// exercise calling the root and getting an image
export default function() {
    group("image_and_root", function() {
        var res = call_root();
        check_response(res, { duration: 500, status: 200 });

        res = retrieve_image();
        check_response(res, { duration: 1000, status: 200 });
    });
};