# Licenses

Pode's core license is MIT, which can be [found here](https://github.com/Badgerati/Pode/blob/develop/LICENSE.txt).

Pode also has several dependencies, some of which are optional and some of which are mandatory - depending on the feature you're using within Pode. For example, if you're using OpenAPI and render the documentation via Swagger or ReDoc then these are mandatory dependencies. However, if you're returning YAML data from a Route then you can either use Pode's inbuilt YAML converter, or you can optionally use [PSYAML](https://github.com/Phil-Factor/PSYaml) or [powershell-yaml](https://github.com/cloudbase/powershell-yaml) and Pode will detect these are installed.

The licenses for Pode dependencies, whether they're optional or mandatory, can be [found here](https://github.com/Badgerati/Pode/tree/develop/licenses), and they are also released alongside Pode's module within a `/licenses` folder.