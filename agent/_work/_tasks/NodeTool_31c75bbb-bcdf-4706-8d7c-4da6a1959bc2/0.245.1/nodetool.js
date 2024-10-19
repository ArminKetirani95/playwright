"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const taskLib = require("azure-pipelines-task-lib/task");
const toolLib = require("azure-pipelines-tool-lib/tool");
const restm = require("typed-rest-client/RestClient");
const telemetry = require("azure-pipelines-tasks-utility-common/telemetry");
const os = require("os");
const path = require("path");
const fs = require("fs");
const force32bit = taskLib.getBoolInput('force32bit', false);
let osPlat = os.platform();
let osArch = getArch();
function run() {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            taskLib.setResourcePath(path.join(__dirname, 'task.json'));
            let versionSource = taskLib.getInput('versionSource', true);
            let versionSpecInput = taskLib.getInput('versionSpec', versionSource == 'spec');
            let versionFilePathInput = taskLib.getInput('versionFilePath', versionSource == 'fromFile');
            let nodejsMirror = taskLib.getInput('nodejsMirror', false);
            const retryCountOnDownloadFails = taskLib.getInput('retryCountOnDownloadFails', false) || "5";
            const delayBetweenRetries = taskLib.getInput('delayBetweenRetries', false) || "1000";
            let versionSpec = getNodeVersion(versionSource, versionSpecInput, versionFilePathInput);
            let checkLatest = taskLib.getBoolInput('checkLatest', false);
            yield getNode(versionSpec, checkLatest, nodejsMirror.replace(/\/$/, ''), parseInt(retryCountOnDownloadFails), parseInt(delayBetweenRetries));
            telemetry.emitTelemetry('TaskHub', 'NodeToolV0', { versionSource, versionSpec, checkLatest, force32bit });
        }
        catch (error) {
            taskLib.setResult(taskLib.TaskResult.Failed, error.message);
        }
    });
}
//
// Basic pattern:
//      if !checkLatest
//          toolPath = check cache
//      if !toolPath
//          if version is a range
//              match = query nodejs.org
//              if !match
//                  fail
//              toolPath = check cache
//          if !toolPath
//              download, extract, and cache
//              toolPath = cacheDir
//      PATH = cacheDir + PATH
//
function getNode(versionSpec, checkLatest, nodejsMirror, retryCountOnDownloadFails, delayBetweenRetries) {
    return __awaiter(this, void 0, void 0, function* () {
        let installedArch = osArch;
        if (toolLib.isExplicitVersion(versionSpec)) {
            checkLatest = false; // check latest doesn't make sense when explicit version
        }
        // check cache
        let toolPath;
        if (!checkLatest) {
            toolPath = toolLib.findLocalTool('node', versionSpec, installedArch);
            // In case if it's darwin arm and toolPath is empty trying to find x64 version
            if (!toolPath && isDarwinArm(osPlat, installedArch)) {
                toolPath = toolLib.findLocalTool('node', versionSpec, 'x64');
            }
        }
        if (!toolPath) {
            let version;
            if (toolLib.isExplicitVersion(versionSpec)) {
                // version to download
                version = versionSpec;
            }
            else {
                // query nodejs.org for a matching version
                version = yield queryLatestMatch(versionSpec, installedArch, nodejsMirror);
                if (!version && isDarwinArm(osPlat, installedArch)) {
                    // nodejs.org does not have an arm64 build for macOS, so we fall back to x64
                    console.log(taskLib.loc('TryRosetta', osPlat, installedArch));
                    version = yield queryLatestMatch(versionSpec, 'x64', nodejsMirror);
                    installedArch = 'x64';
                }
                if (!version) {
                    throw new Error(taskLib.loc('NodeVersionNotFound', versionSpec, osPlat, installedArch));
                }
                // check cache
                toolPath = toolLib.findLocalTool('node', version, installedArch);
            }
            if (!toolPath) {
                // download, extract, cache
                toolPath = yield acquireNode(version, installedArch, nodejsMirror, retryCountOnDownloadFails, delayBetweenRetries);
            }
        }
        //
        // a tool installer initimately knows details about the layout of that tool
        // for example, node binary is in the bin folder after the extract on Mac/Linux.
        // layouts could change by version, by platform etc... but that's the tool installers job
        //
        if (osPlat != 'win32') {
            toolPath = path.join(toolPath, 'bin');
        }
        //
        // prepend the tools path. instructs the agent to prepend for future tasks
        //
        toolLib.prependPath(toolPath);
    });
}
function queryLatestMatch(versionSpec, installedArch, nodejsMirror) {
    return __awaiter(this, void 0, void 0, function* () {
        // node offers a json list of versions
        let dataFileName;
        switch (osPlat) {
            case "linux":
                dataFileName = "linux-" + installedArch;
                break;
            case "darwin":
                dataFileName = "osx-" + installedArch + '-tar';
                break;
            case "win32":
                dataFileName = "win-" + installedArch + '-exe';
                break;
            default: throw new Error(taskLib.loc('UnexpectedOS', osPlat));
        }
        let versions = [];
        let dataUrl = nodejsMirror + "/index.json";
        let rest = new restm.RestClient('vsts-node-tool');
        let nodeVersions = (yield rest.get(dataUrl)).result;
        if (!nodeVersions) {
            // this will be handled by the caller and an error will be thrown
            return null;
        }
        nodeVersions.forEach((nodeVersion) => {
            // ensure this version supports your os and platform
            if (nodeVersion.files.indexOf(dataFileName) >= 0) {
                // versions in the file are prefixed with 'v', which is not valid SemVer
                // remove 'v' so that toolLib.evaluateVersions behaves properly
                nodeVersion.semanticVersion = toolLib.cleanVersion(nodeVersion.version);
                versions.push(nodeVersion.semanticVersion);
            }
        });
        // get the latest version that matches the version spec
        let latestVersion = toolLib.evaluateVersions(versions, versionSpec);
        // In case if that we had not found version that match 
        if (!latestVersion)
            return null;
        return nodeVersions.find(v => v.semanticVersion === latestVersion).version;
    });
}
function acquireNode(version, installedArch, nodejsMirror, retryCountOnDownloadFails, delayBetweenRetries) {
    return __awaiter(this, void 0, void 0, function* () {
        //
        // Download - a tool installer intimately knows how to get the tool (and construct urls)
        //
        version = toolLib.cleanVersion(version);
        const isWin32 = osPlat == 'win32';
        const platform = isWin32 ? 'win' : osPlat;
        const fileName = `node-v${version}-${platform}-${installedArch}`;
        const fileExtension = isWin32 ? '.7z' : '.tar.gz';
        const downloadUrl = `${nodejsMirror}/v${version}/${fileName}${fileExtension}`;
        let downloadPath;
        try {
            console.log("Aquiring Node called");
            console.log("Retry count on download fails: " + retryCountOnDownloadFails + " Retry delay: " + delayBetweenRetries + "ms");
            downloadPath = yield toolLib.downloadToolWithRetries(downloadUrl, null, null, null, retryCountOnDownloadFails, delayBetweenRetries);
        }
        catch (err) {
            if (isWin32 && err['httpStatusCode'] == 404) {
                return yield acquireNodeFromFallbackLocation(version, nodejsMirror, retryCountOnDownloadFails, delayBetweenRetries);
            }
            throw err;
        }
        //
        // Extract
        //
        let extPath;
        if (isWin32) {
            taskLib.assertAgent('2.115.0');
            extPath = taskLib.getVariable('Agent.TempDirectory');
            if (!extPath) {
                throw new Error(taskLib.loc('AgentTempDirNotSet'));
            }
            let _7zPath = path.join(__dirname, '7zr.exe');
            extPath = yield toolLib.extract7z(downloadPath, extPath, _7zPath);
        }
        else {
            extPath = yield toolLib.extractTar(downloadPath);
        }
        //
        // Install into the local tool cache - node extracts with a root folder that matches the fileName downloaded
        //
        let toolRoot = path.join(extPath, fileName);
        return yield toolLib.cacheDir(toolRoot, 'node', version, installedArch);
    });
}
// For non LTS versions of Node, the files we need (for Windows) are sometimes located
// in a different folder than they normally are for other versions.
// Normally the format is similar to: https://nodejs.org/dist/v5.10.1/node-v5.10.1-win-x64.7z
// In this case, there will be two files located at:
//      /dist/v5.10.1/win-x64/node.exe
//      /dist/v5.10.1/win-x64/node.lib
// If this is not the structure, there may also be two files located at:
//      /dist/v0.12.18/node.exe
//      /dist/v0.12.18/node.lib
// This method attempts to download and cache the resources from these alternative locations.
// Note also that the files are normally zipped but in this case they are just an exe
// and lib file in a folder, not zipped.
function acquireNodeFromFallbackLocation(version, nodejsMirror, retryCountOnDownloadFails, delayBetweenRetries) {
    return __awaiter(this, void 0, void 0, function* () {
        // Create temporary folder to download in to
        let tempDownloadFolder = 'temp_' + Math.floor(Math.random() * 2000000000);
        let tempDir = path.join(taskLib.getVariable('agent.tempDirectory'), tempDownloadFolder);
        taskLib.mkdirP(tempDir);
        let exeUrl;
        let libUrl;
        console.log("Aquiring Node from callback called");
        console.log("Retry count on download fails: " + retryCountOnDownloadFails + " Retry delay: " + delayBetweenRetries + "ms");
        try {
            exeUrl = `${nodejsMirror}/v${version}/win-${osArch}/node.exe`;
            libUrl = `${nodejsMirror}/v${version}/win-${osArch}/node.lib`;
            yield toolLib.downloadToolWithRetries(exeUrl, path.join(tempDir, "node.exe"), null, null, retryCountOnDownloadFails, delayBetweenRetries);
            yield toolLib.downloadToolWithRetries(libUrl, path.join(tempDir, "node.lib"), null, null, retryCountOnDownloadFails, delayBetweenRetries);
        }
        catch (err) {
            if (err['httpStatusCode'] &&
                err['httpStatusCode'] == 404) {
                exeUrl = `${nodejsMirror}/v${version}/node.exe`;
                libUrl = `${nodejsMirror}/v${version}/node.lib`;
                yield toolLib.downloadToolWithRetries(exeUrl, path.join(tempDir, "node.exe"), null, null, retryCountOnDownloadFails, delayBetweenRetries);
                yield toolLib.downloadToolWithRetries(libUrl, path.join(tempDir, "node.lib"), null, null, retryCountOnDownloadFails, delayBetweenRetries);
            }
            else {
                throw err;
            }
        }
        return yield toolLib.cacheDir(tempDir, 'node', version, osArch);
    });
}
// Check is the system are darwin arm and rosetta is installed
function isDarwinArm(osPlat, installedArch) {
    if (osPlat === 'darwin' && installedArch === 'arm64') {
        // Check that Rosetta is installed and returns some pid
        const execResult = taskLib.execSync('pgrep', 'oahd');
        return execResult.code === 0 && !!execResult.stdout;
    }
    return false;
}
function getArch() {
    let arch = os.arch();
    if (arch === 'ia32' || force32bit) {
        arch = 'x86';
    }
    return arch;
}
function getNodeVersion(versionSource, versionSpecInput, versionFilePathInput) {
    if (versionSource == 'spec')
        return versionSpecInput;
    return fs.readFileSync(versionFilePathInput, { 'encoding': 'utf8' });
}
run();
