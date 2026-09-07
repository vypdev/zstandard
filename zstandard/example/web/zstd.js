'use strict';

(() => {
    const scriptUrl = document.currentScript?.src
        ?? new URL('zstd.js', document.baseURI).href;
    const workerUrl = new URL('zstd_worker.js', scriptUrl).href;
    let worker = null;
    let nextRequestId = 1;
    const pending = new Map();

    function failPendingRequests() {
        for (const resolve of pending.values()) resolve(null);
        pending.clear();
        worker?.terminate();
        worker = null;
    }

    function getWorker() {
        if (worker !== null) return worker;
        worker = new Worker(workerUrl);
        worker.onmessage = (event) => {
            const resolve = pending.get(event.data.id);
            if (resolve === undefined) return;
            pending.delete(event.data.id);
            resolve(event.data.result);
        };
        worker.onerror = failPendingRequests;
        worker.onmessageerror = failPendingRequests;
        return worker;
    }

    function run(operation, inputData, option) {
        return new Promise((resolve) => {
            const id = nextRequestId++;
            try {
                const inputCopy = inputData.slice();
                pending.set(id, resolve);
                getWorker().postMessage(
                    { id, operation, inputBuffer: inputCopy.buffer, option },
                    [inputCopy.buffer],
                );
            } catch (_) {
                pending.delete(id);
                resolve(null);
            }
        });
    }

    globalThis.compressData = (inputData, compressionLevel) =>
        run('compress', inputData, compressionLevel);
    globalThis.decompressData = (compressedData, maxOutputSize) =>
        run('decompress', compressedData, maxOutputSize);
})();
