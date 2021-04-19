let handle;
function setHandler(h) {
    handle = h;
}

function send(command, payload) {
    const obj = { command, payload };
    console.log("Send: " + JSON.stringify(obj, null, 2));
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

module.exports = {
    send,
    setHandler,
};
