"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.setCurlProxySettings = void 0;
const taskLib = require("azure-pipelines-task-lib/task");
const qs = require("querystring");
const url = require("url");
function toCurlProxy(proxyCfg) {
    let curlProxy;
    if (proxyCfg) {
        if (proxyCfg.proxyUrl) {
            taskLib.debug(`using proxy ${proxyCfg.proxyUrl}`);
            const parsedUrl = url.parse(proxyCfg.proxyUrl);
            const httpEnvVarName = parsedUrl.protocol === 'https:' ? "HTTPS_PROXY" : "HTTP_PROXY";
            let proxyUrl = new URL(proxyCfg.proxyUrl);
            proxyUrl.username = proxyCfg.proxyUsername;
            proxyUrl.password = proxyCfg.proxyPassword;
            curlProxy = {};
            curlProxy.variable = httpEnvVarName;
            curlProxy.setting = proxyUrl.toString();
        }
    }
    return curlProxy;
}
function setCurlProxySettings(proxyConfig) {
    if (taskLib.getVariable("HTTP_PROXY") || taskLib.getVariable("HTTPS_PROXY")) {
        // Short circuit if proxy already set.
        return;
    }
    let curlProxy = toCurlProxy(proxyConfig);
    if (curlProxy) {
        // register the escaped versions of password
        if (proxyConfig.proxyPassword) {
            taskLib.setSecret(qs.escape(proxyConfig.proxyPassword));
        }
        taskLib.setVariable(curlProxy.variable, curlProxy.setting);
    }
}
exports.setCurlProxySettings = setCurlProxySettings;
