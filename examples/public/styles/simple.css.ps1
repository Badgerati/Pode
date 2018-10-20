return (. {
    $date = [DateTime]::UtcNow;

    "body {"
    if ($date.Second % 2 -eq 0) {
        "background-color: rebeccapurple;"
    } else {
        "background-color: red;"
    }
    "}"
})