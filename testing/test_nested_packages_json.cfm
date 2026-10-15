<cfsetting showdebugoutput="false">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfscript>
results = [];
function check(required string name, required boolean passed) {
    arrayAppend(results, {"name": arguments.name, "passed": arguments.passed});
}
work = getTempDirectory() & "staticfiles-nested-" & createUUID() & "/";
directoryCreate(work);
try {
    fileWrite(work & "own.js", "own;", "utf-8");
    fileWrite(work & "child.js", "child;", "utf-8");
    for (parentPacked in [false, true]) {
        obj = new staticfiles.staticFiles(staticDef={
            "scripts": [
                {"name": "own", "debug": work & "own.js", "min": "/own.min.js"},
                {"name": "childScript", "debug": work & "child.js", "min": "/child.min.js"},
                {"name": "loose", "debug": "/loose.js"}
            ],
            "packages": [
                {"name": "child", "min": work & "child-bundle.js", "scripts": ["childScript"]},
                {"name": "unpacked", "scripts": ["loose", "child"]},
                {"name": "parent", "pack": parentPacked, "min": work & "parent-bundle.js", "scripts": ["own", "unpacked", "child"]}
            ]
        }, prefix="[", suffix="]");
        links = obj.getLinks({"parent": 1, "child": 1});
        expected = (parentPacked ? "" : "[/own.min.js]") & "[/loose.js][" & work & "child-bundle.js]" & (parentPacked ? "[" & work & "parent-bundle.js]" : "");
        check("nested links with parent pack=" & parentPacked, links == expected);
        check("debug expands nested packages once", obj.getLinks({"parent": 1}, true) == "[" & work & "own.js][" & work & "child.js][/loose.js]");
        compressed = obj.compress(type="js", overwrite=true, minify=false);
        check("child bundle contains only child source", fileRead(work & "child-bundle.js") == "child;" && arrayLen(compressed[1].files) == 1);
        check("parent bundle excludes nested packages", !parentPacked ? !compressed[3].saved : compressed[3].saved && fileRead(work & "parent-bundle.js") == "own;" && arrayLen(compressed[3].files) == 1);
    }
    cyclic = new staticfiles.staticFiles(staticDef={"scripts": [{"name": "loose", "min": "/loose.js"}], "packages": [
        {"name": "a", "scripts": ["b"]}, {"name": "b", "scripts": ["a", "loose"]}
    ]}, prefix="[", suffix="]");
    check("circular package references terminate without duplicate links", cyclic.getLinks({"a": 1}) == "[/loose.js]");
}
catch (any e) { arrayAppend(results, {"name": "Unexpected error", "passed": false, "message": e.message, "detail": e.detail}); }
finally { directoryDelete(work, true); }
passed = true;
for (result in results) { if (!result.passed) passed = false; }
writeOutput(serializeJSON({"passed": passed, "tests": results}));
</cfscript>