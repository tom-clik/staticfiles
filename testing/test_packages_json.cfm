<cfsetting showdebugoutput="false" requesttimeout="180">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfscript>
results = [];
function check(required string name, required boolean passed) {
    arrayAppend(results, {"name": arguments.name, "passed": arguments.passed});
}
work = getTempDirectory() & "staticfiles-test " & createUUID() & "/";
directoryCreate(work);
try {
    for (kind in ["css", "js"]) {
        first = kind == "css" ? ".first { color: red; }" : "function first() { return 1; };";
        second = kind == "css" ? ".second { color: blue; }" : "function second() { return 2; };";
        fileWrite(work & "first." & kind, first, "utf-8");
        fileWrite(work & "second." & kind, second, "utf-8");
        obj = new staticfiles.staticFiles({
            "scripts": [
                {"name": "first", "debug": work & "first." & kind, "min": work & "missing-min." & kind},
                {"name": "second", "debug": work & "second." & kind},
                {"name": "excluded", "min": work & "missing." & kind, "packageExclude": true}
            ],
            "packages": [{"name": "bundle", "min": work & "bundle." & kind, "scripts": ["first", "second", "excluded"]}]
        });
        compressed = obj.compress(type=kind);
        output = fileRead(work & "bundle." & kind, "utf-8");
        check(kind & " package compresses both files and excludes missing external file", compressed[1].saved && arrayLen(compressed[1].files) == 2 && find("first", output) > 0 && find("second", output) > find("first", output) && len(output) < len(first & second));
        check(kind & " package prefers debug and supports entries without min", compressed[1].files[1] == work & "first." & kind && compressed[1].files[2] == work & "second." & kind);
        skipped = obj.compress(type=kind);
        check(kind & " existing package is preserved", !skipped[1].saved && fileRead(work & "bundle." & kind, "utf-8") == output);
        raw = obj.compress(type=kind, overwrite=true, minify=false);
        check(kind & " overwrite and minify=false preserve concatenated source", raw[1].saved && fileRead(work & "bundle." & kind, "utf-8") == first & second);
        fallback = new staticfiles.staticFiles({"scripts": [{"name": "first", "min": work & "first." & kind}], "packages": [{"name": "fallback", "min": work & "fallback." & kind, "scripts": ["first"]}]}).compress(type=kind, minify=false);
        check(kind & " package falls back to min when debug is absent", fallback[1].saved && fileRead(work & "fallback." & kind, "utf-8") == first);
    }
}
catch (any e) {
    arrayAppend(results, {"name": "Unexpected error", "passed": false, "message": e.message, "detail": e.detail});
}
finally { directoryDelete(work, true); }
passed = true;
for (result in results) { if (!result.passed) passed = false; }
writeOutput(serializeJSON({"passed": passed, "tests": results}));
</cfscript>
