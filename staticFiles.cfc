/**
# StaticFiles component

Allows for easy inclusion of static files (js,css) in a web page

See docs/static_files.md

*/

component {
	/**
	 * Constructor
	 *
	 * @staticDef  Struct of static file definitions
	 * @prefix     The prefix for each item. Change according to whther this is css or js. See setCSS() rather than set these
	 * @suffix     The suffix for each item. See prefix
	 *
	 */
	public staticFiles function init(
		required struct staticDef,
		string prefix="#chr(9)#<script src=""",
		string suffix="""></script>#chr(13)##chr(10)#"
		) {

		variables.prefix = arguments.prefix;
		variables.suffix = arguments.suffix;

		variables.scripts = arguments.staticDef.scripts;
		if (structKeyExists(arguments.staticDef, "packages")) {
			variables.packages = arguments.staticDef.packages;
		}
		else {
			variables.packages = [];
		}

		variables.patternObj = CreateObject( "java", "java.util.regex.Pattern" );
		// generic debug pattern will remove anything between #DEBUG AND /#DEBUG
		// it leaves the comment tags in for the minimiser to deal with.
		variables.debugpattern = variables.patternObj.compile("\##DEBUG.*?\/\##DEBUG",variables.patternObj.MULTILINE + variables.patternObj.UNIX_LINES + variables.patternObj.DOTALL);
		// JS console pattern removes all logging type entries. Use warn or error to leave stuff in
		variables.consolepattern = variables.patternObj.compile("^\s*console\.(log|group.*?|table|time|trace)\(.*?\)\s*;\s*$",variables.patternObj.MULTILINE + variables.patternObj.UNIX_LINES);


		/* create lookup caches keyed by name for scripts and packages */

		variables.scriptCache = {};
		variables.packageCache = {};

		try{

			for (local.script in variables.scripts) {
				// defaults
				StructAppend(local.script, {"packageExclude":0,"compress":0}, false);

				if (! StructKeyExists(local.script,"name")) {
					throw("No name defined for script in json definition");
				}
				variables.scriptCache[local.script.name] = local.script;

				if (local.script.packageExclude && !StructKeyExists(local.script,"min")) {
					throw("No min (the src) defined for script #local.script.name# in json definition");
				}
				else if (!local.script.packageExclude && !StructKeyExists(local.script,"min") && !StructKeyExists(local.script,"debug")) {
					throw("No min or debug defined for script in json definition");
				}
			}

			for (local.script in variables.packages) {
				StructAppend(local.script, {"pack":true}, false);
				if (! StructKeyExists(local.script,"name")) {
					throw("No name defined for package in json definition");
				}
				if (local.script.pack && !StructKeyExists(local.script,"min")) {
					throw("No min (the src) defined for package in json definition");
				}
				variables.packageCache[local.script.name] = local.script;

			}
		}
		catch (any e) {
			local.extendedinfo = {"error"=e};
			throw(
				extendedinfo = SerializeJSON(local.extendedinfo),
				message      = "Error:" & e.message,
				detail       = e.detail
			);
		}

		return this;
	}

	/** Set the options to the defaults for css */
	public void function setCss() {
		variables.prefix="#chr(9)#<link rel=""stylesheet"" href=""";
		variables.suffix=""">#chr(13)##chr(10)#";
	}

	public string function getLinks(required struct scripts, boolean debug=false) {

		local.packagesIncluded = {};
		local.scriptsInPackage = {};
		local.ret = "";

		/* check if any packages in script def  */
		for (local.scriptname in arguments.scripts) {
			if (StructKeyExists(variables.packageCache, local.scriptname)) {
				local.packagesIncluded[local.scriptname] = 1;
				/* add all scripts from package to list. They may have dependencies */
				local.package = variables.packageCache[local.scriptname];
				for (local.script2 in local.package.scripts) {
					if (StructKeyExists(variables.scriptCache, local.script2)) {
						local.script = variables.scriptCache[local.script2];
						arguments.scripts[local.script2] = 1;
						if (local.package.pack && !local.script.packageExclude) {
							local.scriptsInPackage[local.script2] = 1;
						}
					}
				}
			}
		}

		/* add required scripts and also note if a script is a package */
		for (local.script in arguments.scripts) {
			if (StructKeyExists(variables.scriptCache, local.script) AND
				StructKeyExists(variables.scriptCache[local.script], "requires")) {
				addRequired(arguments.scripts,variables.scriptCache[local.script].requires);
			}
		}

		for (local.script in variables.scripts) {
			//writeDump(local.script);
			if (StructKeyExists(arguments.scripts, local.script.name)) {

				if (arguments.debug) {
					local.scriptSrc = StructKeyExists(variables.scriptCache[local.script.name], "debug") ? variables.scriptCache[local.script.name]["debug"] : variables.scriptCache[local.script.name]["min"];
					local.ret &= variables.prefix &local.scriptSrc  & variables.suffix;
				}
				else if (! StructKeyExists(local.scriptsInPackage, local.script.name) || local.script.packageExclude) {
					local.ret &= variables.prefix & variables.scriptCache[local.script.name]["min"] & variables.suffix;
				}
			}


		}

		for (local.script in variables.packages) {
			if (StructKeyExists(arguments.scripts, local.script.name)) {
				if (!arguments.debug  && StructKeyExists(local.packagesIncluded,local.script.name) && variables.packageCache[local.script.name].pack) {
					local.ret &= variables.prefix & variables.packageCache[local.script.name]["min"] & variables.suffix;
				}
			}
		}



		return local.ret;

	}

	private void function addRequired(required struct scripts, required string required) {
		for (local.requiredScript in listToArray(arguments.required)) {
			arguments.scripts[local.requiredScript] = 1;
			// check recursion -- NB let it recurse so we get ALL requirements
			if (structKeyExists(variables.scriptCache, local.requiredScript)
				AND structKeyExists(variables.scriptCache[local.requiredScript], "requires")) {
				addRequired(arguments.scripts, variables.scriptCache[local.requiredScript]["requires"]);
			}
		}
	}

	/**
	 * @hint      Load a definition file from disk.
	 *
	 * @defFile  Full path to definition file
	 *
	 */
	public struct function loadDefFile(defFile) {
		if (NOT fileExists(arguments.defFile)) {
			throw("Static files definition file #arguments.defFile# not found");
		}
		local.tempData = fileRead(arguments.defFile);
		try {
			local.jsonData = deserializeJSON(local.tempData);
		}
		catch (Any e) {
			throw("Unable to parse static files definition file #arguments.defFile#");
		}

		return local.jsonData;
	}

	/**
	 * @hint        Compress individual scripts and packages using local esbuild (see compressSource()).
	 *
	 * First compress scripts marked compress=1 from debug to min. Then for each package, concatenate files, compress, and save to file specified
	 *  in "min" field for the package.
	 *
	 *
	 *
	 * @type        css|javascript
	 * @overwrite   Allow overwrite of existing file. Recommended to leave this OFF.
	 *              You should always bump the version
	 * @return      Array of results (result.name, result.saved [won't save if
	 *              pack=false or all scripts are excluded from packages],
	 *              result.filename, result.files)
	 */
	public array function compress(type="css",boolean overwrite=false, struct mappings=[=], boolean minify=true) {

		local.results = [];
		local.jobs = [];
		// Individual outputs must exist before packages that include them are assembled.
		for (local.script in variables.scripts) {
			if (!local.script.compress) continue;
			if (!structKeyExists(local.script, "debug") || !structKeyExists(local.script, "min")) {
				throw(message="Script #local.script.name# marked compress=1 requires debug and min paths");
			}
			arrayAppend(local.jobs, {"name": local.script.name, "min": local.script.min, "source": local.script.debug, "pack": true});
		}
		for (local.package in variables.packages) {
			arrayAppend(local.jobs, local.package);
		}
		for (local.package in local.jobs) {

			local.res = {"name": local.package.name,"saved": false};

			if (local.package.pack) {

				local.outputFile = filePath(local.package.min,arguments.mappings);
				local.res["filename"] = local.outputFile;

				if (FileExists(local.outputFile) AND NOT arguments.overwrite) {
					ArrayAppend(local.results, local.res);
					continue;
				}

				local.res["files"]=[];
				local.res["raw"] = 0;// sum total size of raw packages
				// TO DO: check package scripts are in order. Use them if they are
				local.out = "";
				if (structKeyExists(local.package, "source")) {
					local.filename = filePath(local.package.source, arguments.mappings);
					if (getCanonicalPath(local.filename) == getCanonicalPath(local.outputFile)) {
						throw(message="Source and destination must differ for script #local.package.name#");
					}
					if (!fileExists(local.filename)) {
						throw(message="File #local.filename# not found for script #local.package.name#. Please check mappings.");
					}
					local.res.raw = getFileInfo(local.filename).size;
					local.out = fileRead(local.filename, "utf-8");
					arrayAppend(local.res.files, local.filename);
				}
				else {
					for (local.script in variables.scripts) {

						if (ArrayFind(local.package.scripts, local.script.name)) {
							if (!local.script.packageExclude) {
								local.filename = filePath(local.script.min,arguments.mappings);
								if (!FileExists(local.filename)) {
									Throw(message="File #local.filename# not found for script #local.script.name#. Please check mappings if this doesn't make sense.");
								}
								local.res.raw += getFileInfo(local.filename).size;
								local.out &= FileRead(local.filename,"utf-8");
								ArrayAppend(local.res.files, local.filename);
							}
						}
					}
					}
				if (local.out != "" || structKeyExists(local.package, "source")) {

					local.out =	variables.debugpattern.matcher(local.out).replaceAll("");

					if (arguments.minify) {
						try {
							if (arguments.type == "css") {
								local.compressed = minifiyCSS(local.out);
							}
							else {
								local.compressed = minifiyJS(local.out);
							}
						}
						catch (any e) {
							local.extendedinfo = e.keyExists("extendedinfo") && isJSON(e.extendedinfo) ? deserializeJSON(e.extendedinfo) : {};
							StructAppend(local.extendedinfo, {"tagcontext"=e.tagcontext}, false);

							throw(
								extendedinfo = SerializeJSON(local.extendedinfo),
								message      = "Unable to minify file #local.outputFile#:" & e.message,
								detail       = e.detail,
								errorcode    = "compress.2"
							);
						}
					}
					else {
						local.compressed =local.out;
					}

					try {
						local.outputDirectory = getDirectoryFromPath(local.outputFile);
						if (!directoryExists(local.outputDirectory)) {
							directoryCreate(local.outputDirectory, true);
						}
						FileWrite(local.outputFile, local.compressed, "utf-8");
					}
					catch (any e) {
						throw(
							message      = "Unable to save file #local.outputFile#:" & e.message,
							detail       = e.detail,
							errorcode    = "compress.1"
						);
					}

					local.res["compressed"] = getFileInfo(local.outputFile).size;;
					local.res["saved"] = true;
				}
			}

			ArrayAppend(local.results, local.res);

		}

		return local.results;
	}

	public string function minifiyCSS(required string css) {

		return compressSource(input=arguments.css, type="css");
	}

	public string function minifiyJS(required string js) {
		arguments.js = removeJsComments(arguments.js);
		return compressSource(input=arguments.js, type="js");
	}

	public string function removeJsComments(required string js) {
		return variables.consolepattern.matcher(arguments.js).replaceAll("");
	}

	/** Minify source with Node.js and esbuild available through npx on PATH. */
	private string function compressSource(required string input, required string type) {
		local.tempDirectory = getTempDirectory() & "staticfiles-" & createUUID() & "/";
		local.fileIn = local.tempDirectory & "input." & arguments.type;
		local.fileOut = local.tempDirectory & "output." & arguments.type;
		local.cmd = (server.os.name CONTAINS "Windows") ? "npx.cmd" : "npx";
		local.stdout = "";
		local.stderr = "";

		directoryCreate(local.tempDirectory);
		try {
			fileWrite(local.fileIn, arguments.input, "utf-8");
			cfexecute(
				name = local.cmd,
				arguments = [
					"esbuild",
					local.fileIn,
					"--minify",
					"--outfile=#local.fileOut#"
				],
				directory = local.tempDirectory,
				variable = "local.stdout",
				errorVariable = "local.stderr",
				timeout = 60
			);

			// esbuild writes progress to stderr even on success. Require a new output file.
			if (!fileExists(local.fileOut)) {
				throw(
					message = "Error compressing source with esbuild",
					detail = local.stderr,
					extendedinfo = serializeJSON({"stdout": local.stdout, "stderr": local.stderr})
				);
			}
			return fileRead(local.fileOut, "utf-8");
		}
		finally {
			directoryDelete(local.tempDirectory, true);
		}
	}
	/**
	 * Get absolute path of a script from a url
	 * @src    src of script -- be default this will be expanded
	 * @mappings  Specified full paths to match agains the src
	 */
	public string function filePath(required string src, required struct mappings) {

		var ret = arguments.src;
		for (var mapping in arguments.mappings) {
			if (reFind("^#mapping#", arguments.src)) {
				ret = replace(arguments.src, mapping, arguments.mappings[mapping]);
			}
		}
		return ret;

	}

}
