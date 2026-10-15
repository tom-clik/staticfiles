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
        source = kind == "css" ? ".individual { color: red; margin: 0px; }" : "function individual() { return 40 + 2; };";
        fileWrite(work & "source." & kind, source, "utf-8");
        mappings = {"/fixtures/": work};
        obj = new staticfiles.staticFiles({"scripts": [
            {"name": "individual", "debug": "/fixtures/source." & kind, "min": "/fixtures/nested/" & kind & "/individual/min." & kind, "compress": 1},
            {"name": "defaultOff", "debug": work & "missing", "min": work & "default." & kind},
            {"name": "explicitOff", "debug": work & "missing", "min": work & "off." & kind, "compress": 0}
        ], "packages": [{"name": "bundle", "min": "/fixtures/nested/" & kind & "/packages/bundle." & kind, "scripts": ["individual"]}]});
        compressed = obj.compress(type=kind, mappings=mappings);
        check(kind & " missing individual and package output directories are created", directoryExists(work & "nested/" & kind & "/individual/") && directoryExists(work & "nested/" & kind & "/packages/"));
        output = fileRead(work & "nested/" & kind & "/individual/min." & kind, "utf-8");
        check(kind & " individual compresses debug into mapped min before package", arrayLen(compressed) == 2 && compressed[1].name == "individual" && compressed[1].saved && compressed[2].saved && find("individual", fileRead(work & "nested/" & kind & "/packages/bundle." & kind)) > 0 && len(output) < len(source));
        check(kind & " omitted and zero compress flags skip scripts", !fileExists(work & "default." & kind) && !fileExists(work & "off." & kind));
        check(kind & " result records source and sizes", compressed[1].files[1] == work & "source." & kind && compressed[1].raw == getFileInfo(work & "source." & kind).size && compressed[1].compressed == getFileInfo(work & "nested/" & kind & "/individual/min." & kind).size);
        skipped = obj.compress(type=kind, mappings=mappings);
        check(kind & " existing individual output preserved", !skipped[1].saved && fileRead(work & "nested/" & kind & "/individual/min." & kind, "utf-8") == output);
        raw = obj.compress(type=kind, mappings=mappings, overwrite=true, minify=false);
        check(kind & " overwrite without minification copies debug source", raw[1].saved && fileRead(work & "nested/" & kind & "/individual/min." & kind, "utf-8") == source);
    }
    for (definition in [
        {"name": "missingDebug", "min": work & "bad.css", "compress": 1},
        {"name": "samePath", "debug": work & "source.css", "min": work & "source.css", "compress": 1},
        {"name": "missingFile", "debug": work & "missing.css", "min": work & "bad.css", "compress": 1}
    ]) {
        rejected = false;
        try { new staticfiles.staticFiles({"scripts": [definition]}).compress(overwrite=true); }
        catch (any e) { rejected = true; }
        check(definition.name & " is rejected", rejected);
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
