# StaticFiles component {#static_files}
 
Allows for easy inclusion of static files (js,css) in a web page

## Usage

### Configuration

Configure a definition along the lines of the defaults. See [Scripts](#static_files_scripts){.xref} and [Packages](#static_files_scripts){.xref} below for details.

The script array is the order in which the scripts must appear.

### Use

Instantiate the component in a permanent scope and initialise with the definition and your required prefix/suffix

To add files of packages, add to a "set" (a struct with a redundant key), e.g.

    js_static["myscript"] = 1
 
To get the script/style tags for an HTML page, use the `getLinks()` method, e.g.

    getLinks(js_static);

To use the "debug" versions (if specified) call the method with `getLinks(js_static,true);`

#### Scripts {#static_files_scripts}

Scripts (meaning css or js files) are defined as an array of objects with the following keys

:name
The name by which the script is referenced
:min
src of the production version of the script (usually minimised or such). Can only be omitted if the script is in a bundled package.
:debug
The debug version of the script. Can be omitted if a min version is specified. In debug mode, scripts are always included seperately even if in a bundled package
:requires
List or array of required scripts. Always include all required scripts even if it's something as common as jquery
:compress (boolean)
Set to `1` to compress this individual script from `debug` into `min` when `compress()` runs. Defaults to `0`. Both paths are required and must differ. Individual files are processed before packages; existing outputs are preserved unless `overwrite=true`. The `mappings`, `type`, and `minify` options apply to both individual files and packages.
:packageExclude (boolean)
Always show separate file even if in a package that is bundled. Typically the "min" script will be served from a CDN

Note the order of the array is the order the scripts appear in the page.

Sample script entry

```
{
    "debug": "/_assets/js/jquery.validate.js",
    "min": "https://cdnjs.cloudflare.com/ajax/libs/jquery-validate/1.19.1/jquery.validate.js",
    "name": "validate",
    "packageExclude": 1,
    "requires": "jquery"
}
```

#### Packages {#static_files_scripts}

Groups of scripts can be defined in packages. These are added in the same way as normal scripts, e.g. for the package defined below:

    js_static["main"] = 1

These can include scripts like jquery that won't be "bundled". For any given script definition, the packageExclude
field can be set to true to ensure the individual script is always used, usually from a CDN.

Set `pack:0` (or `pack:false`) on a package to include its files separately and skip package compression. Packages without a `min` path automatically use `pack:false`. Separate files use each script's `min` source when available, otherwise its `debug` source.

A package's `scripts` array can also list package names, including nested packages. Each nested package follows its own `pack` setting: packed packages add their `min` link, and unpacked packages include their individual files. Nested packages and their files are never folded into the parent bundle. Shared or circular package references are included only once. File links follow the script definition order; bundle links follow the package definition order. Debug mode expands all packages into individual files.

Packages read each script's `debug` source when specified, otherwise its `min` source. A packaged script can specify only `debug`.

Use `compress()` to compress opted-in individual scripts and concatenate and minify packages with local esbuild. Compression requires Node.js and `npx` on the ColdFusion/Lucee server PATH, permission to run `cfexecute`, and a writable temporary directory. Install esbuild where npx can resolve it; otherwise npx may need network access to fetch it. Both CSS and JavaScript use `npx esbuild --minify`. Set `minify=false` to concatenate without running esbuild. Gulp or other systems can also be used.

```
packages": [
        {
            "scripts": [
                "jquery",
                "jqueryui",
                "validate",
                "fuzzy",
                "metaforms",
                "datatables",
                "select2"
            ],
            "pack":false,
            "name":"main"
        }
    ]
```

## Compression tests

Run these scripts through the local CFML server. Each returns JSON with an overall `passed` flag and individual test results:

- [Minifier tests](http://localhost:8089/staticfiles/testing/test_minify_json.cfm): CSS and JavaScript minification, console removal, empty input, invalid JavaScript, and cleanup after failure.
- [Package tests](http://localhost:8089/staticfiles/testing/test_packages_json.cfm): CSS and JavaScript packages, input order, package exclusions, overwrite protection, and concatenation without minification.

The tests use temporary files and remove them afterwards. They require the same Node.js, npx, and cfexecute setup as production compression.

Individual compression tests: [JSON results](http://localhost:8089/staticfiles/testing/test_individual_json.cfm). The real-file test page supports an optional individual entry filter, e.g. [cms_columns](http://localhost:8089/staticfiles/testing/test_compressCSS.cfm?filter=cms_columns), and writes to 	esting/_output/ without overwriting existing files.
