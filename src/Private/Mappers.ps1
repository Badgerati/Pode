function Get-PodeContentType {
    param(
        [Parameter()]
        [string]
        $Extension,

        [switch]
        $DefaultIsNull
    )
    return $(if ($DefaultIsNull) {
            [Pode.PodeMimeTypes]::tryGet($Extension, $null )
        }
        else {
            [Pode.PodeMimeTypes]::Get($Extension)
        }
    )
}

function Get-PodeStatusDescription {
    param(
        [Parameter()]
        [int]
        $StatusCode
    )

    switch ($StatusCode) {
        100 { return 'Continue' }
        101 { return 'Switching Protocols' }
        102 { return 'Processing' }
        103 { return 'Early Hints' }
        200 { return 'OK' }
        201 { return 'Created' }
        202 { return 'Accepted' }
        203 { return 'Non-Authoritative Information' }
        204 { return 'No Content' }
        205 { return 'Reset Content' }
        206 { return 'Partial Content' }
        207 { return 'Multi-Status' }
        208 { return 'Already Reported' }
        226 { return 'IM Used' }
        300 { return 'Multiple Choices' }
        301 { return 'Moved Permanently' }
        302 { return 'Found' }
        303 { return 'See Other' }
        304 { return 'Not Modified' }
        305 { return 'Use Proxy' }
        306 { return 'Switch Proxy' }
        307 { return 'Temporary Redirect' }
        308 { return 'Permanent Redirect' }
        400 { return 'Bad Request' }
        401 { return 'Unauthorized' }
        402 { return 'Payment Required' }
        403 { return 'Forbidden' }
        404 { return 'Not Found' }
        405 { return 'Method Not Allowed' }
        406 { return 'Not Acceptable' }
        407 { return 'Proxy Authentication Required' }
        408 { return 'Request Timeout' }
        409 { return 'Conflict' }
        410 { return 'Gone' }
        411 { return 'Length Required' }
        412 { return 'Precondition Failed' }
        413 { return 'Payload Too Large' }
        414 { return 'URI Too Long' }
        415 { return 'Unsupported Media Type' }
        416 { return 'Range Not Satisfiable' }
        417 { return 'Expectation Failed' }
        418 { return "I'm a Teapot" }
        419 { return 'Page Expired' }
        420 { return 'Enhance Your Calm' }
        421 { return 'Misdirected Request' }
        422 { return 'Unprocessable Entity' }
        423 { return 'Locked' }
        424 { return 'Failed Dependency' }
        425 { return 'Too Early' }
        426 { return 'Upgrade Required' }
        428 { return 'Precondition Required' }
        429 { return 'Too Many Requests' }
        431 { return 'Request Header Fields Too Large' }
        440 { return 'Login Time-out' }
        450 { return 'Blocked by Windows Parental Controls' }
        451 { return 'Unavailable For Legal Reasons' }
        495 { return 'SSL Certificate Error' }
        500 { return 'Internal Server Error' }
        501 { return 'Not Implemented' }
        502 { return 'Bad Gateway' }
        503 { return 'Service Unavailable' }
        504 { return 'Gateway Timeout' }
        505 { return 'HTTP Version Not Supported' }
        506 { return 'Variant Also Negotiates' }
        507 { return 'Insufficient Storage' }
        508 { return 'Loop Detected' }
        510 { return 'Not Extended' }
        511 { return 'Network Authentication Required' }
        526 { return 'Invalid SSL Certificate' }
        default { return ([string]::Empty) }
    }
}