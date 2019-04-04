function Get-PodeRandomName
{
    $adjs = @(
        "admiring",
        "agitated",
        "blissful",
        "dazzling",
        "ecstatic",
        "eloquent",
        "friendly",
        "gracious",
        "hardcore",
        "laughing",
        "peaceful",
        "pedantic",
        "reverent",
        "romantic",
        "trusting",
        "vigilant",
        "vigorous",
        "wizardly",
        "youthful"
    )

    $names = @(
        "almeida",
        "babbage",
        "bardeen",
        "shannon",
        "davinci",
        "feynman",
        "galileo",
        "goodall",
        "hawking",
        "hermann",
        "hodgkin",
        "hypatia",
        "jackson",
        "johnson",
        "kapitsa",
        "keldysh",
        "khorana",
        "lalande",
        "lamport",
        "leavitt",
        "lumiere",
        "mcnulty",
        "meitner",
        "mestorf",
        "murdock",
        "neumann",
        "noether",
        "pasteur",
        "perlman",
        "poitras",
        "ptolemy",
        "ritchie",
        "shirley",
        "swanson",
        "swirles",
        "vaughan",
        "volhard",
        "villani",
        "wescoff",
        "wozniak"
    )

    $adjsRand = (Get-Random -Minimum 0 -Maximum $adjs.Length)
    $namesRand = (Get-Random -Minimum 0 -Maximum $names.Length)

    return "$($adjs[$adjsRand])_$($names[$namesRand])"
}