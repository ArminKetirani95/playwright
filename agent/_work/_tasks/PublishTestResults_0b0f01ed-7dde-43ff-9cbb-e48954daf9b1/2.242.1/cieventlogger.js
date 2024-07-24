"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.publishEvent = exports.fireConsolidatedCi = exports.addToConsolidatedCi = void 0;
const tl = require("azure-pipelines-task-lib/task");
const area = 'TestExecution';
const feature = 'PublishTestResultsTask';
const consolidatedCiData = {};
function getDefaultProps() {
    return {
        releaseuri: tl.getVariable('Release.ReleaseUri'),
        releaseid: tl.getVariable('Release.ReleaseId'),
        builduri: tl.getVariable('Build.BuildUri'),
        buildid: tl.getVariable('Build.Buildid'),
        osType: tl.osType()
    };
}
function addToConsolidatedCi(key, value) {
    consolidatedCiData[key] = value;
}
exports.addToConsolidatedCi = addToConsolidatedCi;
function fireConsolidatedCi() {
    publishEvent('publishTestResultsTaskConsolidatedCiEvent', consolidatedCiData);
}
exports.fireConsolidatedCi = fireConsolidatedCi;
function publishEvent(subFeature, properties) {
    try {
        properties.subFeature = subFeature;
        _writeTelemetry(area, feature, Object.assign(getDefaultProps(), properties));
    }
    catch (err) {
        tl.debug('Unable to publish telemetry due to lower agent version.');
    }
}
exports.publishEvent = publishEvent;
function _writeTelemetry(area, feature, properties) {
    // The telemetry command was added in agent version 2.120.0.
    try {
        var splitVersion = (process.env.AGENT_VERSION || '').split('.');
        var major = parseInt(splitVersion[0] || '0');
        var minor = parseInt(splitVersion[1] || '0');
        if (major > 2 || (major == 2 && minor >= 120)) {
            console.log(`##vso[telemetry.publish area=${area};feature=${feature}]${JSON.stringify(properties)}`);
        }
        else {
            tl.debug(`cannot write telemetry in agent ${process.env.AGENT_VERSION}`);
        }
    }
    catch (err) {
        tl.debug(`Error in writing telemetry : ${err}`);
    }
}
