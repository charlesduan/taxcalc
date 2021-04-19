const readline = require('readline');
const fs = require('fs');

let handle;
function setHandler(h) {
    handle = h;
}

function processLine(line) {
    console.log("Processing " + line);
    obj = JSON.parse(line);
    handle(obj.command, obj.payload);
}

function send(command, payload) {
    console.log("Send: " + JSON.stringify({ command, payload }, null, 2));
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

function setfd(read, write) {
    readStream = readline.createInterface({
        input: fs.createReadStream(null, { fd: read }),
        crlfDelay: Infinity
    });
    writeStream = fs.createWriteStream(null, { fd: write });

    readStream.on('line', processLine);
}

module.exports = {
    send,
    setHandler,
    setfd,
};
