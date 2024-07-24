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
exports.TestResultsPublisher = void 0;
const fs = require("fs");
const os = require("os");
const path = require("path");
const tl = require("azure-pipelines-task-lib/task");
const ci = require("./cieventlogger");
let uuid = require('uuid');
class TestResultsPublisher {
    constructor(matchingTestResultsFiles, mergeResults, failTaskOnFailedTests, platform, config, testRunTitle, publishRunAttachments, testRunner, testRunSystem, failTaskOnFailureToPublishResults) {
        this.matchingTestResultsFiles = matchingTestResultsFiles.slice(0);
        this.mergeResults = mergeResults;
        this.failTaskOnFailedTests = failTaskOnFailedTests;
        this.platform = platform;
        this.config = config;
        this.testRunTitle = testRunTitle;
        this.publishRunAttachments = publishRunAttachments;
        this.testRunner = testRunner;
        this.testRunSystem = testRunSystem;
        this.failTaskOnFailureToPublishResults = failTaskOnFailureToPublishResults;
    }
    publishResultsThroughExe() {
        return __awaiter(this, void 0, void 0, function* () {
            const testResultsPublisherTool = tl.tool(this.getTestResultsPublisherLocation());
            const envVars = this.getEnvironmentVariables();
            const args = this.getArguments(this.matchingTestResultsFiles);
            if (testResultsPublisherTool == null || args == null) {
                return 20000;
            }
            testResultsPublisherTool.arg(args);
            const exitCode = yield testResultsPublisherTool.exec({ env: envVars, ignoreReturnCode: true });
            return exitCode;
        });
    }
    getTestResultsPublisherLocation() {
        return path.join(__dirname, 'modules/TestResultsPublisher.exe');
    }
    getArguments(matchingTestResultsFiles) {
        const responseFilePath = this.createResponseFile(matchingTestResultsFiles);
        if (responseFilePath == null) {
            return null;
        }
        // Adding '@' because this is a response file argument
        const args = ['@' + responseFilePath];
        return args;
    }
    createResponseFile(matchingTestResultsFiles) {
        let responseFilePath = null;
        try {
            const agentTempDirectory = tl.getVariable('Agent.TempDirectory');
            // The response file is being created in agent temp directory so that it is automatically deleted after.
            responseFilePath = path.join(agentTempDirectory, uuid.v1() + '.txt');
            // Adding quotes around matching file names
            matchingTestResultsFiles = this.modifyMatchingFileName(matchingTestResultsFiles);
            // Preparing File content
            const fileContent = os.EOL + matchingTestResultsFiles.join(os.EOL);
            // Writing matching file names in the response file
            fs.writeFileSync(responseFilePath, fileContent);
        }
        catch (ex) {
            // Log telemetry and return null path
            ci.addToConsolidatedCi('exception', ex);
            tl.warning("Exception while writing to response file: " + ex);
            return null;
        }
        return responseFilePath;
    }
    modifyMatchingFileName(matchingTestResultsFiles) {
        for (let i = 0; i < this.matchingTestResultsFiles.length; i++) {
            // We need to add quotes around the file name because the file name can contain spaces.
            // The quotes will be handled by response file reader.
            matchingTestResultsFiles[i] = '\"' + matchingTestResultsFiles[i] + '\"';
        }
        return matchingTestResultsFiles;
    }
    getEnvironmentVariables() {
        let envVars = {};
        envVars = this.addToProcessEnvVars(envVars, 'collectionurl', tl.getVariable('System.TeamFoundationCollectionUri'));
        envVars = this.addToProcessEnvVars(envVars, 'accesstoken', tl.getEndpointAuthorizationParameter('SystemVssConnection', 'AccessToken', false));
        envVars = this.addToProcessEnvVars(envVars, 'testrunner', this.testRunner);
        envVars = this.addToProcessEnvVars(envVars, 'mergeresults', this.mergeResults);
        envVars = this.addToProcessEnvVars(envVars, 'failtaskonfailedtests', this.failTaskOnFailedTests);
        envVars = this.addToProcessEnvVars(envVars, 'platform', this.platform);
        envVars = this.addToProcessEnvVars(envVars, 'config', this.config);
        envVars = this.addToProcessEnvVars(envVars, 'publishrunattachments', this.publishRunAttachments);
        envVars = this.addToProcessEnvVars(envVars, 'testruntitle', this.testRunTitle);
        envVars = this.addToProcessEnvVars(envVars, 'testrunsystem', this.testRunSystem);
        envVars = this.addToProcessEnvVars(envVars, 'projectname', tl.getVariable('System.TeamProject'));
        envVars = this.addToProcessEnvVars(envVars, 'pullrequesttargetbranch', tl.getVariable('System.PullRequest.TargetBranch'));
        envVars = this.addToProcessEnvVars(envVars, 'owner', tl.getVariable('Build.RequestedFor'));
        envVars = this.addToProcessEnvVars(envVars, 'buildid', tl.getVariable('Build.BuildId'));
        envVars = this.addToProcessEnvVars(envVars, 'builduri', tl.getVariable('Build.BuildUri'));
        envVars = this.addToProcessEnvVars(envVars, 'releaseuri', tl.getVariable('Release.ReleaseUri'));
        envVars = this.addToProcessEnvVars(envVars, 'releaseenvironmenturi', tl.getVariable('Release.EnvironmentUri'));
        envVars = this.addToProcessEnvVars(envVars, 'phasename', tl.getVariable('System.PhaseName'));
        envVars = this.addToProcessEnvVars(envVars, 'phaseattempt', tl.getVariable('System.PhaseAttempt'));
        envVars = this.addToProcessEnvVars(envVars, 'stagename', tl.getVariable('System.StageName'));
        envVars = this.addToProcessEnvVars(envVars, 'stageattempt', tl.getVariable('System.StageAttempt'));
        envVars = this.addToProcessEnvVars(envVars, 'jobname', tl.getVariable('System.JobName'));
        envVars = this.addToProcessEnvVars(envVars, 'jobattempt', tl.getVariable('System.JobAttempt'));
        envVars = this.addToProcessEnvVars(envVars, 'jobidentifier', tl.getVariable('System.JobIdentifier'));
        envVars = this.addToProcessEnvVars(envVars, 'agenttempdirectory', tl.getVariable('Agent.TempDirectory'));
        envVars = this.addToProcessEnvVars(envVars, 'failtaskonfailuretopublishresults', this.failTaskOnFailureToPublishResults);
        // Setting proxy details
        envVars = this.addToProcessEnvVars(envVars, "proxyurl", tl.getVariable('agent.proxyurl'));
        envVars = this.addToProcessEnvVars(envVars, "proxyusername", tl.getVariable('agent.proxyusername'));
        envVars = this.addToProcessEnvVars(envVars, "proxypassword", tl.getVariable('agent.proxypassword'));
        envVars = this.addToProcessEnvVars(envVars, "proxybypasslist", tl.getVariable('agent.proxybypasslist'));
        return envVars;
    }
    addToProcessEnvVars(envVars, name, value) {
        if (!this.isNullEmptyOrUndefined(value)) {
            envVars[name] = value;
        }
        return envVars;
    }
    isNullEmptyOrUndefined(obj) {
        return obj === null || obj === '' || obj === undefined;
    }
}
exports.TestResultsPublisher = TestResultsPublisher;
