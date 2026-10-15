<cfsetting showdebugoutput="false" requesttimeout="180">
<cfcontent type="application/json; charset=utf-8" reset="true">
<cfscript>
results = [];
function check(required string name, required boolean passed) {
    arrayAppend(results, {"name": arguments.name, "passed": arguments.passed});
}
try {
    obj = new staticfiles.staticFiles({"scripts": []});
    css = "/* remove me */ .example { color: red; margin: 0px 0px 0px 0px; }";
    output = obj.minifiyCSS(css);
    check("CSS is smaller and retains selector", len(output) < len(css) && find(".example", output) > 0 && find("remove me", output) == 0);
    js = "console.log('debug');" & chr(10) & "function answer() { return 40 + 2; }";
    output = obj.minifiyJS(js);
    check("JavaScript is minified and console logging removed", len(output) < len(js) && find("answer", output) > 0 && find("console.log", output) == 0);
    check("Empty CSS is supported", trim(obj.minifiyCSS("")) == "");
    check("Empty JavaScript is supported", trim(obj.minifiyJS("")) == "");
    before = directoryList(getTempDirectory(), false, "path", "staticfiles-*");
    rejected = false;
    try { obj.minifiyJS("function broken( {"); }
    catch (any e) { rejected = true; }
    check("Invalid JavaScript raises an error", rejected);
    after = directoryList(getTempDirectory(), false, "path", "staticfiles-*");
    check("Failed compression cleans temporary directories", arrayLen(before) == arrayLen(after));
}
catch (any e) {
    arrayAppend(results, {"name": "Unexpected error", "passed": false, "message": e.message, "detail": e.detail});
}
passed = true;
for (result in results) { if (!result.passed) passed = false; }
writeOutput(serializeJSON({"passed": passed, "tests": results}));
</cfscript>
