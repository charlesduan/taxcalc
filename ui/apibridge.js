const readline = require('readline');
const fs = require('fs');

let handle;
function setHandler(h) {
    handle = h;
}

function processLine(line) {
    obj = JSON.parse(line);
    handle(obj.command, obj.payload);
}

function send(command, payload) {
    writeStream.write(JSON.stringify({ command, payload }) + "\n");
    return;
    switch (command) {
        case "selectPage":
            selectPage(payload.page);
            break;
        case "addLineBox":
            handle("drawLineBox", {
                line: payload.toolbar.line,
                id: payload.toolbar.line,
                pos: payload.pos
            });
            break;
        case "removeLine":
            handle("removeLineBox", {
                id: payload.id
            });
            break;
        case "toolbarUpdate":
            break;
    }
}

function selectPage(page) {
    if (page == 1) {
        handle("drawLineBox", {
            line: "1",
            id: "1",
            pos: [ 72, 72, 144, 144 ],
        });
    }
}

let readStream, writeStream;
let rawReadStream;

function setfd(read, write) {

    rawReadStream = fs.createReadStream(null, { fd: read });
    readStream = readline.createInterface({
        input: rawReadStream,
        crlfDelay: Infinity,
    });
    writeStream = fs.createWriteStream(null, { fd: write });

    readStream.on('line', processLine);
}

function shutdown() {
    if (readStream) {
        readStream.close();
        rawReadStream.close();
        writeStream.close();
    }
}

module.exports = {
    send,
    setHandler,
    setfd,
    shutdown,
};
