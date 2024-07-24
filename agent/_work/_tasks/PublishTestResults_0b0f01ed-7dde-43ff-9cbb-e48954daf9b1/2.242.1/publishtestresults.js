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
const path = require("path");
const fs = require("fs");
const semver = require("semver");
const publishTestResultsTool = require("./publishtestresultstool");
const tl = require("azure-pipelines-task-lib/task");
const ci = require("./cieventlogger");
const MERGE_THRESHOLD = 100;
const TESTRUN_SYSTEM = 'VSTS - PTR';
function isNullOrWhitespace(input) {
    if (typeof input === 'undefined' || input === null) {
        return true;
    }
    return input.replace(/\s/g, '').length < 1;
}
function publish(testRunner, resultFiles, mergeResults, failTaskOnFailedTests, platform, config, runTitle, publishRunAttachments, testRunSystem, failTaskOnFailureToPublishResults) {
    var properties = {};
    properties['type'] = testRunner;
    if (mergeResults) {
        properties['mergeResults'] = mergeResults;
    }
    if (platform) {
        properties['platform'] = platform;
    }
    if (config) {
        properties['config'] = config;
    }
    if (runTitle) {
        properties['runTitle'] = runTitle;
    }
    if (publishRunAttachments) {
        properties['publishRunAttachments'] = publishRunAttachments;
    }
    if (resultFiles) {
        properties['resultFiles'] = resultFiles;
    }
    if (failTaskOnFailedTests) {
        properties['failTaskOnFailedTests'] = failTaskOnFailedTests;
    }
    if (failTaskOnFailureToPublishResults) {
        properties['failTaskOnFailureToPublishResults'] = failTaskOnFailureToPublishResults;
    }
    properties['testRunSystem'] = testRunSystem;
    tl.command('results.publish', properties, '');
}
function getDotNetVersion() {
    let dotnet;
    const dotnetPath = tl.which('dotnet', false);
    if (dotnetPath) {
        try {
            dotnet = tl.tool(dotnetPath);
            dotnet.arg('--version');
            return dotnet.execSync().stdout.trim();
        }
        catch (err) { }
    }
    return '';
}
function run() {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            tl.setResourcePath(path.join(__dirname, 'task.json'));
            const testRunner = tl.getInput('testRunner', true);
            const testResultsFiles = tl.getDelimitedInput('testResultsFiles', '\n', true);
            const mergeResults = tl.getInput('mergeTestResults');
            const platform = tl.getInput('platform');
            const config = tl.getInput('configuration');
            const testRunTitle = tl.getInput('testRunTitle');
            const publishRunAttachments = tl.getInput('publishRunAttachments');
            const failTaskOnFailedTests = tl.getInput('failTaskOnFailedTests');
            const failTaskOnMissingResultsFile = tl.getBoolInput('failTaskOnMissingResultsFile');
            const failTaskOnFailureToPublishResults = tl.getInput('failTaskOnFailureToPublishResults');
            let searchFolder = tl.getInput('searchFolder');
            tl.debug('testRunner: ' + testRunner);
            tl.debug('testResultsFiles: ' + testResultsFiles);
            tl.debug('mergeResults: ' + mergeResults);
            tl.debug('platform: ' + platform);
            tl.debug('config: ' + config);
            tl.debug('testRunTitle: ' + testRunTitle);
            tl.debug('publishRunAttachments: ' + publishRunAttachments);
            tl.debug('failTaskOnFailedTests: ' + failTaskOnFailedTests);
            tl.debug('failTaskOnMissingResultsFile: ' + failTaskOnMissingResultsFile);
            tl.debug('failTaskOnFailureToPublishResults: ' + failTaskOnFailureToPublishResults);
            if (isNullOrWhitespace(searchFolder)) {
                searchFolder = tl.getVariable('System.DefaultWorkingDirectory');
            }
            if (tl.getVariable('System.DefaultWorkingDirectory') && (!path.isAbsolute(searchFolder))) {
                searchFolder = path.join(tl.getVariable('System.DefaultWorkingDirectory'), searchFolder);
            }
            // Sending allowBrokenSymbolicLinks as true, so we don't want to throw error when symlinks are broken.
            // And can continue with other files if there are any.
            const findOptions = {
                allowBrokenSymbolicLinks: true,
                followSpecifiedSymbolicLink: true,
                followSymbolicLinks: true
            };
            const matchingTestResultsFiles = tl.findMatch(searchFolder, testResultsFiles, findOptions);
            const testResultsFilesCount = matchingTestResultsFiles ? matchingTestResultsFiles.length : 0;
            tl.debug(`Detected ${testResultsFilesCount} test result files`);
            ci.addToConsolidatedCi('testRunner', testRunner);
            ci.addToConsolidatedCi('failTaskOnFailedTests', failTaskOnFailedTests);
            ci.addToConsolidatedCi('mergeResultsUserPreference', mergeResults);
            ci.addToConsolidatedCi('config', config);
            ci.addToConsolidatedCi('platform', platform);
            ci.addToConsolidatedCi('testResultsFilesCount', testResultsFilesCount);
            ci.addToConsolidatedCi('failTaskOnMissingResultsFile', failTaskOnMissingResultsFile);
            ci.addToConsolidatedCi('failTaskOnFailureToPublishResults', failTaskOnFailureToPublishResults);
            const dotnetVersion = getDotNetVersion();
            ci.addToConsolidatedCi('dotnetVersion', dotnetVersion);
            const forceMerge = testResultsFilesCount > MERGE_THRESHOLD;
            if (forceMerge) {
                tl.debug('Detected large number of test result files. Merged all of them into a single file and published a single test run to optimize for test result publish performance instead of publishing hundreds of test runs');
            }
            if (testResultsFilesCount === 0) {
                if (failTaskOnMissingResultsFile) {
                    tl.setResult(tl.TaskResult.Failed, tl.loc('NoMatchingFilesFound', testResultsFiles));
                }
                else {
                    tl.warning(tl.loc('NoMatchingFilesFound', testResultsFiles));
                }
                ci.addToConsolidatedCi('noResultsFileFound', true);
            }
            else {
                const osType = tl.osType();
                // This variable can be set as build variable to force the task to use command flow
                const isExeFlowOverridden = tl.getVariable('PublishTestResults.OverrideExeFlow');
                tl.debug('OS type: ' + osType);
                if (osType === 'Windows_NT' && isExeFlowOverridden != 'true') {
                    const testResultsPublisher = new publishTestResultsTool.TestResultsPublisher(matchingTestResultsFiles, forceMerge ? true.toString() : mergeResults, failTaskOnFailedTests, platform, config, testRunTitle, publishRunAttachments, testRunner, TESTRUN_SYSTEM, failTaskOnFailureToPublishResults);
                    const exitCode = yield testResultsPublisher.publishResultsThroughExe();
                    tl.debug("Exit code of TestResultsPublisher: " + exitCode);
                    if (exitCode === 20000) {
                        // The exe returns with exit code: 20000 if the Feature flag is off or if it fails to fetch the Feature flag value
                        publish(testRunner, matchingTestResultsFiles, forceMerge ? true.toString() : mergeResults, failTaskOnFailedTests, platform, config, testRunTitle, publishRunAttachments, TESTRUN_SYSTEM, failTaskOnFailureToPublishResults);
                    }
                    else if (exitCode === 40000) {
                        // The exe returns with exit code: 40000 if there are test failures found and failTaskOnFailedTests is true
                        ci.addToConsolidatedCi('failedTestsInRun', true);
                        tl.setResult(tl.TaskResult.Failed, tl.loc('ErrorFailTaskOnFailedTests'));
                    }
                    if (exitCode !== 20000) {
                        // Doing it only for test results published using TestResultPublisher tool.
                        // For other publishes, publishing to evidence store happens as part of results.publish command itself.
                        readAndPublishTestRunSummaryToEvidenceStore(testRunner);
                    }
                }
                else {
                    publish(testRunner, matchingTestResultsFiles, forceMerge ? true.toString() : mergeResults, failTaskOnFailedTests, platform, config, testRunTitle, publishRunAttachments, TESTRUN_SYSTEM, failTaskOnFailureToPublishResults);
                }
            }
            tl.setResult(tl.TaskResult.Succeeded, '');
        }
        catch (err) {
            tl.setResult(tl.TaskResult.Failed, err);
        }
        finally {
            ci.fireConsolidatedCi();
        }
    });
}
function readAndPublishTestRunSummaryToEvidenceStore(testRunner) {
    try {
        const agentVersion = tl.getVariable('Agent.Version');
        if (semver.lt(agentVersion, "2.164.0")) {
            throw "Required agent version greater than or equal to 2.164.0";
        }
        var tempPath = tl.getVariable('Agent.TempDirectory');
        var testRunSummaryPath = path.join(tempPath, "PTR_TEST_RUNSUMMARY.json");
        var testRunSummary = fs.readFileSync(testRunSummaryPath, 'utf-8');
        var properties = {};
        properties['name'] = "PublishTestResults";
        properties['testrunner'] = testRunner;
        properties['testrunsummary'] = testRunSummary;
        properties['description'] = "Test Results published from Publish Test Results tool";
        tl.command('results.publishtoevidencestore', properties, '');
    }
    catch (error) {
        tl.debug(`Unable to publish the test run summary to evidencestore, error details:${error}`);
    }
}
run();
