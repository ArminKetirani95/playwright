"use strict";
//
// UseNode: 
//     Optionally install version at runtime, setup proxy and setup auth
//     This allows for natural cmd line steps in yaml after "using" that eco-system
//     since proxy vars and auth is setup for the rest of the job
//
// https://github.com/Microsoft/azure-pipelines-yaml/blob/master/design/use-statement.md
//
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
//import * as toolLib from 'vsts-task-tool-lib/tool';
const installer = require("./installer");
const proxyutil = require("./proxyutil");
const path = require("path");
function run() {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            //
            // Version is optional.  If supplied, install / use from the tool cache
            // If not supplied then task is still used to setup proxy, auth, etc...
            //
            taskLib.setResourcePath(path.join(__dirname, 'task.json'));
            const version = taskLib.getInput('version', false);
            const retryCountOnDownloadFails = taskLib.getInput('retryCountOnDownloadFails', false) || "5";
            const delayBetweenRetries = taskLib.getInput('delayBetweenRetries', false) || "1000";
            if (version) {
                const checkLatest = taskLib.getBoolInput('checkLatest', false);
                yield installer.getNode(version, checkLatest, parseInt(retryCountOnDownloadFails), parseInt(delayBetweenRetries));
            }
            const proxyCfg = taskLib.getHttpProxyConfiguration();
            if (proxyCfg) {
                proxyutil.setCurlProxySettings(proxyCfg);
            }
        }
        catch (error) {
            taskLib.setResult(taskLib.TaskResult.Failed, error.message);
        }
    });
}
run();
