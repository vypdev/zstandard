'use strict';

importScripts('zstd_core.js');

self.onmessage = async (event) => {
    const { id, operation, inputBuffer, option } = event.data;
    try {
        const input = new Uint8Array(inputBuffer);
        const result = operation === 'compress'
            ? await compressData(input, option)
            : await decompressData(input, option);
        if (result === null) {
            self.postMessage({ id, result: null });
        } else {
            self.postMessage({ id, result }, [result.buffer]);
        }
    } catch (_) {
        self.postMessage({ id, result: null });
    }
};
