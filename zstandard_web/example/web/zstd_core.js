var Module=typeof zstdWasmModule!="undefined"?zstdWasmModule:{};var ENVIRONMENT_IS_WEB=typeof window=="object";var ENVIRONMENT_IS_WORKER=typeof importScripts=="function";var ENVIRONMENT_IS_NODE=typeof process=="object"&&typeof process.versions=="object"&&typeof process.versions.node=="string"&&process.type!="renderer";if(ENVIRONMENT_IS_NODE){}var moduleOverrides=Object.assign({},Module);var arguments_=[];var thisProgram="./this.program";var quit_=(status,toThrow)=>{throw toThrow};var scriptDirectory="";function locateFile(path){if(Module["locateFile"]){return Module["locateFile"](path,scriptDirectory)}return scriptDirectory+path}var readAsync,readBinary;if(ENVIRONMENT_IS_NODE){var fs=require("fs");var nodePath=require("path");scriptDirectory=__dirname+"/";readBinary=filename=>{filename=isFileURI(filename)?new URL(filename):nodePath.normalize(filename);var ret=fs.readFileSync(filename);return ret};readAsync=(filename,binary=true)=>{filename=isFileURI(filename)?new URL(filename):nodePath.normalize(filename);return new Promise((resolve,reject)=>{fs.readFile(filename,binary?undefined:"utf8",(err,data)=>{if(err)reject(err);else resolve(binary?data.buffer:data)})})};if(!Module["thisProgram"]&&process.argv.length>1){thisProgram=process.argv[1].replace(/\\/g,"/")}arguments_=process.argv.slice(2);if(typeof module!="undefined"){module["exports"]=Module}quit_=(status,toThrow)=>{process.exitCode=status;throw toThrow}}else if(ENVIRONMENT_IS_WEB||ENVIRONMENT_IS_WORKER){if(ENVIRONMENT_IS_WORKER){scriptDirectory=self.location.href}else if(typeof document!="undefined"&&document.currentScript){scriptDirectory=document.currentScript.src}if(scriptDirectory.startsWith("blob:")){scriptDirectory=""}else{scriptDirectory=scriptDirectory.substr(0,scriptDirectory.replace(/[?#].*/,"").lastIndexOf("/")+1)}{if(ENVIRONMENT_IS_WORKER){readBinary=url=>{var xhr=new XMLHttpRequest;xhr.open("GET",url,false);xhr.responseType="arraybuffer";xhr.send(null);return new Uint8Array(xhr.response)}}readAsync=url=>{if(isFileURI(url)){return new Promise((resolve,reject)=>{var xhr=new XMLHttpRequest;xhr.open("GET",url,true);xhr.responseType="arraybuffer";xhr.onload=()=>{if(xhr.status==200||xhr.status==0&&xhr.response){resolve(xhr.response);return}reject(xhr.status)};xhr.onerror=reject;xhr.send(null)})}return fetch(url,{credentials:"same-origin"}).then(response=>{if(response.ok){return response.arrayBuffer()}return Promise.reject(new Error(response.status+" : "+response.url))})}}}else{}var out=Module["print"]||console.log.bind(console);var err=Module["printErr"]||console.error.bind(console);Object.assign(Module,moduleOverrides);moduleOverrides=null;if(Module["arguments"])arguments_=Module["arguments"];if(Module["thisProgram"])thisProgram=Module["thisProgram"];var wasmBinary=Module["wasmBinary"];var wasmMemory;var ABORT=false;var HEAP8,HEAPU8,HEAP16,HEAPU16,HEAP32,HEAPU32,HEAPF32,HEAPF64;function updateMemoryViews(){var b=wasmMemory.buffer;Module["HEAP8"]=HEAP8=new Int8Array(b);Module["HEAP16"]=HEAP16=new Int16Array(b);Module["HEAPU8"]=HEAPU8=new Uint8Array(b);Module["HEAPU16"]=HEAPU16=new Uint16Array(b);Module["HEAP32"]=HEAP32=new Int32Array(b);Module["HEAPU32"]=HEAPU32=new Uint32Array(b);Module["HEAPF32"]=HEAPF32=new Float32Array(b);Module["HEAPF64"]=HEAPF64=new Float64Array(b)}var __ATPRERUN__=[];var __ATINIT__=[];var __ATPOSTRUN__=[];var runtimeInitialized=false;function preRun(){var preRuns=Module["preRun"];if(preRuns){if(typeof preRuns=="function")preRuns=[preRuns];preRuns.forEach(addOnPreRun)}callRuntimeCallbacks(__ATPRERUN__)}function initRuntime(){runtimeInitialized=true;callRuntimeCallbacks(__ATINIT__)}function postRun(){var postRuns=Module["postRun"];if(postRuns){if(typeof postRuns=="function")postRuns=[postRuns];postRuns.forEach(addOnPostRun)}callRuntimeCallbacks(__ATPOSTRUN__)}function addOnPreRun(cb){__ATPRERUN__.unshift(cb)}function addOnInit(cb){__ATINIT__.unshift(cb)}function addOnPostRun(cb){__ATPOSTRUN__.unshift(cb)}var runDependencies=0;var runDependencyWatcher=null;var dependenciesFulfilled=null;function addRunDependency(id){runDependencies++;Module["monitorRunDependencies"]?.(runDependencies)}function removeRunDependency(id){runDependencies--;Module["monitorRunDependencies"]?.(runDependencies);if(runDependencies==0){if(runDependencyWatcher!==null){clearInterval(runDependencyWatcher);runDependencyWatcher=null}if(dependenciesFulfilled){var callback=dependenciesFulfilled;dependenciesFulfilled=null;callback()}}}function abort(what){Module["onAbort"]?.(what);what="Aborted("+what+")";err(what);ABORT=true;what+=". Build with -sASSERTIONS for more info.";var e=new WebAssembly.RuntimeError(what);throw e}var dataURIPrefix="data:application/octet-stream;base64,";var isDataURI=filename=>filename.startsWith(dataURIPrefix);var isFileURI=filename=>filename.startsWith("file://");function findWasmBinary(){var f="zstd.wasm";if(!isDataURI(f)){return locateFile(f)}return f}var wasmBinaryFile;function getBinarySync(file){if(file==wasmBinaryFile&&wasmBinary){return new Uint8Array(wasmBinary)}if(readBinary){return readBinary(file)}throw"both async and sync fetching of the wasm failed"}function getBinaryPromise(binaryFile){if(!wasmBinary){return readAsync(binaryFile).then(response=>new Uint8Array(response),()=>getBinarySync(binaryFile))}return Promise.resolve().then(()=>getBinarySync(binaryFile))}function instantiateArrayBuffer(binaryFile,imports,receiver){return getBinaryPromise(binaryFile).then(binary=>WebAssembly.instantiate(binary,imports)).then(receiver,reason=>{err(`failed to asynchronously prepare wasm: ${reason}`);abort(reason)})}function instantiateAsync(binary,binaryFile,imports,callback){if(!binary&&typeof WebAssembly.instantiateStreaming=="function"&&!isDataURI(binaryFile)&&!isFileURI(binaryFile)&&!ENVIRONMENT_IS_NODE&&typeof fetch=="function"){return fetch(binaryFile,{credentials:"same-origin"}).then(response=>{var result=WebAssembly.instantiateStreaming(response,imports);return result.then(callback,function(reason){err(`wasm streaming compile failed: ${reason}`);err("falling back to ArrayBuffer instantiation");return instantiateArrayBuffer(binaryFile,imports,callback)})})}return instantiateArrayBuffer(binaryFile,imports,callback)}function getWasmImports(){return{a:wasmImports}}function createWasm(){var info=getWasmImports();function receiveInstance(instance,module){wasmExports=instance.exports;wasmMemory=wasmExports["c"];updateMemoryViews();addOnInit(wasmExports["d"]);removeRunDependency("wasm-instantiate");return wasmExports}addRunDependency("wasm-instantiate");function receiveInstantiationResult(result){receiveInstance(result["instance"])}if(Module["instantiateWasm"]){try{return Module["instantiateWasm"](info,receiveInstance)}catch(e){err(`Module.instantiateWasm callback failed with error: ${e}`);return false}}wasmBinaryFile??=findWasmBinary();instantiateAsync(wasmBinary,wasmBinaryFile,info,receiveInstantiationResult);return{}}var callRuntimeCallbacks=callbacks=>{callbacks.forEach(f=>f(Module))};var noExitRuntime=Module["noExitRuntime"]||true;var __emscripten_memcpy_js=(dest,src,num)=>HEAPU8.copyWithin(dest,src,src+num);var getHeapMax=()=>2147483648;var alignMemory=(size,alignment)=>Math.ceil(size/alignment)*alignment;var growMemory=size=>{var b=wasmMemory.buffer;var pages=(size-b.byteLength+65535)/65536|0;try{wasmMemory.grow(pages);updateMemoryViews();return 1}catch(e){}};var _emscripten_resize_heap=requestedSize=>{var oldSize=HEAPU8.length;requestedSize>>>=0;var maxHeapSize=getHeapMax();if(requestedSize>maxHeapSize){return false}for(var cutDown=1;cutDown<=4;cutDown*=2){var overGrownHeapSize=oldSize*(1+.2/cutDown);overGrownHeapSize=Math.min(overGrownHeapSize,requestedSize+100663296);var newSize=Math.min(maxHeapSize,alignMemory(Math.max(requestedSize,overGrownHeapSize),65536));var replacement=growMemory(newSize);if(replacement){return true}}return false};var wasmImports={b:__emscripten_memcpy_js,a:_emscripten_resize_heap};var wasmExports=createWasm();var ___wasm_call_ctors=()=>(___wasm_call_ctors=wasmExports["d"])();var _malloc=Module["_malloc"]=a0=>(_malloc=Module["_malloc"]=wasmExports["f"])(a0);var _free=Module["_free"]=a0=>(_free=Module["_free"]=wasmExports["g"])(a0);var _ZSTD_isError=Module["_ZSTD_isError"]=a0=>(_ZSTD_isError=Module["_ZSTD_isError"]=wasmExports["h"])(a0);var _ZSTD_compressBound=Module["_ZSTD_compressBound"]=a0=>(_ZSTD_compressBound=Module["_ZSTD_compressBound"]=wasmExports["i"])(a0);var _ZSTD_compress=Module["_ZSTD_compress"]=(a0,a1,a2,a3,a4)=>(_ZSTD_compress=Module["_ZSTD_compress"]=wasmExports["j"])(a0,a1,a2,a3,a4);var _ZSTD_createDStream=Module["_ZSTD_createDStream"]=()=>(_ZSTD_createDStream=Module["_ZSTD_createDStream"]=wasmExports["k"])();var _ZSTD_freeDStream=Module["_ZSTD_freeDStream"]=a0=>(_ZSTD_freeDStream=Module["_ZSTD_freeDStream"]=wasmExports["l"])(a0);var _ZSTD_DStreamOutSize=Module["_ZSTD_DStreamOutSize"]=()=>(_ZSTD_DStreamOutSize=Module["_ZSTD_DStreamOutSize"]=wasmExports["m"])();var _ZSTD_initDStream=Module["_ZSTD_initDStream"]=a0=>(_ZSTD_initDStream=Module["_ZSTD_initDStream"]=wasmExports["n"])(a0);var _ZSTD_decompressStream=Module["_ZSTD_decompressStream"]=(a0,a1,a2)=>(_ZSTD_decompressStream=Module["_ZSTD_decompressStream"]=wasmExports["o"])(a0,a1,a2);var calledRun;var calledPrerun;dependenciesFulfilled=function runCaller(){if(!calledRun)run();if(!calledRun)dependenciesFulfilled=runCaller};function run(){if(runDependencies>0){return}if(!calledPrerun){calledPrerun=1;preRun();if(runDependencies>0){return}}function doRun(){if(calledRun)return;calledRun=1;Module["calledRun"]=1;if(ABORT)return;initRuntime();Module["onRuntimeInitialized"]?.();postRun()}if(Module["setStatus"]){Module["setStatus"]("Running...");setTimeout(()=>{setTimeout(()=>Module["setStatus"](""),1);doRun()},1)}else{doRun()}}if(Module["preInit"]){if(typeof Module["preInit"]=="function")Module["preInit"]=[Module["preInit"]];while(Module["preInit"].length>0){Module["preInit"].pop()()}}run();

// Promise that resolves when the module is ready
let moduleReady = new Promise((resolve) => {
    if (typeof Module !== 'undefined' && Module.calledRun) {
        // Module already initialized
        resolve();
    } else {
        // Wait for module initialization
        const originalOnRuntimeInitialized = Module.onRuntimeInitialized || function() {};
        Module.onRuntimeInitialized = function() {
            originalOnRuntimeInitialized();
            resolve();
        };
    }
});

async function compressData(inputData, compressionLevel) {
    await moduleReady;

    if (!(inputData instanceof Uint8Array)
        || !Number.isInteger(compressionLevel)
        || compressionLevel < 1
        || compressionLevel > 22) {
        return null;
    }

    let inputPtr = 0;
    let outputPtr = 0;
    try {
        inputPtr = Module._malloc(Math.max(inputData.length, 1));
        if (!inputPtr) return null;
        Module.HEAPU8.set(inputData, inputPtr);

        const outputBufferSize = Number(Module._ZSTD_compressBound(inputData.length));
        if (!Number.isSafeInteger(outputBufferSize) || outputBufferSize <= 0) {
            return null;
        }
        outputPtr = Module._malloc(outputBufferSize);
        if (!outputPtr) return null;

        const compressedSize = Number(Module._ZSTD_compress(
            outputPtr,
            outputBufferSize,
            inputPtr,
            inputData.length,
            compressionLevel
        ));
        if (Module._ZSTD_isError(compressedSize) !== 0 || compressedSize <= 0) {
            console.error('Compression error, error code: ', compressedSize);
            return null;
        }
        return new Uint8Array(
            Module.HEAPU8.buffer,
            outputPtr,
            compressedSize
        ).slice();
    } finally {
        if (inputPtr) Module._free(inputPtr);
        if (outputPtr) Module._free(outputPtr);
    }
}

async function decompressData(compressedData, maxOutputSize = 256 * 1024 * 1024) {
    await moduleReady;

    if (!(compressedData instanceof Uint8Array)
        || !Number.isSafeInteger(maxOutputSize)
        || maxOutputSize < 0
        || compressedData.length === 0) {
        return null;
    }

    // ZSTD_inBuffer and ZSTD_outBuffer contain three wasm32 size_t/pointer
    // fields each. Keep their allocation and field access local to the Worker.
    const bufferStructSize = 3 * Uint32Array.BYTES_PER_ELEMENT;
    let compressedPtr = 0;
    let inputBufferPtr = 0;
    let outputBufferPtr = 0;
    let outputChunkPtr = 0;
    let stream = 0;
    try {
        compressedPtr = Module._malloc(compressedData.length);
        inputBufferPtr = Module._malloc(bufferStructSize);
        outputBufferPtr = Module._malloc(bufferStructSize);
        stream = Module._ZSTD_createDStream();
        if (!compressedPtr || !inputBufferPtr || !outputBufferPtr || !stream) {
            return null;
        }
        Module.HEAPU8.set(compressedData, compressedPtr);

        const initialization = Number(Module._ZSTD_initDStream(stream));
        if (Module._ZSTD_isError(initialization) !== 0) return null;

        const recommendedChunkSize = Number(Module._ZSTD_DStreamOutSize());
        if (!Number.isSafeInteger(recommendedChunkSize)
            || recommendedChunkSize <= 0) {
            return null;
        }
        const outputChunkSize = Math.max(
            1,
            Math.min(recommendedChunkSize, Math.max(maxOutputSize, 1)),
        );
        outputChunkPtr = Module._malloc(outputChunkSize);
        if (!outputChunkPtr) return null;

        const writeField = (structPtr, field, value) => {
            Module.HEAPU32[(structPtr >>> 2) + field] = value;
        };
        const readField = (structPtr, field) =>
            Module.HEAPU32[(structPtr >>> 2) + field];

        writeField(inputBufferPtr, 0, compressedPtr);
        writeField(inputBufferPtr, 1, compressedData.length);
        writeField(inputBufferPtr, 2, 0);

        const chunks = [];
        let totalLength = 0;
        let previousInputPosition = -1;
        let previousOutputLength = -1;
        while (true) {
            writeField(outputBufferPtr, 0, outputChunkPtr);
            writeField(outputBufferPtr, 1, outputChunkSize);
            writeField(outputBufferPtr, 2, 0);

            const remaining = Number(Module._ZSTD_decompressStream(
                stream,
                outputBufferPtr,
                inputBufferPtr,
            ));
            if (Module._ZSTD_isError(remaining) !== 0) return null;

            const inputPosition = readField(inputBufferPtr, 2);
            const produced = readField(outputBufferPtr, 2);
            if (inputPosition > compressedData.length
                || produced > outputChunkSize
                || totalLength + produced > maxOutputSize) {
                return null;
            }
            if (produced > 0) {
                chunks.push(new Uint8Array(
                    Module.HEAPU8.buffer,
                    outputChunkPtr,
                    produced,
                ).slice());
                totalLength += produced;
            }

            const allInputConsumed = inputPosition === compressedData.length;
            if (remaining === 0 && allInputConsumed) {
                const result = new Uint8Array(totalLength);
                let offset = 0;
                for (const chunk of chunks) {
                    result.set(chunk, offset);
                    offset += chunk.length;
                }
                return result;
            }

            const madeProgress = inputPosition !== previousInputPosition
                || totalLength !== previousOutputLength;
            if (!madeProgress || (allInputConsumed && produced === 0)) {
                return null;
            }
            previousInputPosition = inputPosition;
            previousOutputLength = totalLength;
        }
    } finally {
        if (stream) Module._ZSTD_freeDStream(stream);
        if (compressedPtr) Module._free(compressedPtr);
        if (inputBufferPtr) Module._free(inputBufferPtr);
        if (outputBufferPtr) Module._free(outputBufferPtr);
        if (outputChunkPtr) Module._free(outputChunkPtr);
    }
}
