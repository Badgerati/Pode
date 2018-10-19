return (. {
    $date = [DateTime]::UtcNow;

    "console.log(`""
    if ($date.Second % 2 -eq 0) {
        "hello, world!"
    } else {
        "goodbye, world!"
    }
    "`")"
})