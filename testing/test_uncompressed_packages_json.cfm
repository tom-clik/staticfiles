<cfsetting showdebugoutput="false">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfscript>
results = [];
for (mode in ["explicit", "automatic", "missingMinOverridesPack"]) {
    package = {"name": "bundle", "scripts": ["first", "second", "third"]};
    if (mode == "explicit") { package.pack = 0; package.min = "/bundle.min.js"; }
    if (mode == "missingMinOverridesPack") package.pack = true;
    obj = new staticfiles.staticFiles(staticDef={
        "scripts": [
            {"name": "first", "debug": "/first.js", "min": "/first.min.js"},
            {"name": "second", "debug": "/second.js"},
            {"name": "third", "min": "/third.min.js"}
        ],
        "packages": [package]
    }, prefix="[", suffix="]");
    links = obj.getLinks({"bundle": 1});

    compressed = obj.compress();
    arrayAppend(results, {"name": mode & " includes separate files in order", "passed": links == "[/first.min.js][/second.js][/third.min.js]"});
    arrayAppend(results, {"name": mode & " skips package output", "passed": arrayLen(compressed) == 1 && !compressed[1].saved && !structKeyExists(compressed[1], "filename")});
}
passed = true;
for (result in results) { if (!result.passed) passed = false; }
writeOutput(serializeJSON({"passed": passed, "tests": results}));
</cfscript>