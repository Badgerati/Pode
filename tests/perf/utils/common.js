import http from "k6/http";
import { check } from "k6";

export let urlbase = 'http://localhost:8085';

export function check_response(res, opts) {
    opts = (opts || { duration: 800, status: 200 });
    opts.duration = (opts.duration || 800);
    opts.status = (opts.status || 200);

    let checks = {};
    checks[`Status is ${opts.status}`] = (res) => res.status === opts.status;
    checks[`Duration OK (<${opts.duration}ms)`] = (res) => res.timings.duration < opts.duration;

    return check(res, checks);
};

export function call_endpoint(url, name) {
    name = (name || url);
    return http.get(url, { tags: { "name": name } });
}