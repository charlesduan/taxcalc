const Canvas = require("canvas");
const fs = require("fs");
const gui = require("@nodegui/nodegui");

const pdfjs = require("pdfjs-dist/es5/build/pdf.js");

const data = new Uint8Array(fs.readFileSync("f1040.pdf"));

const loadingTask = pdfjs.getDocument({
    data,
    cMapUrl: "node_modules/pdfjs-dist/cmaps/",
    cMapPacked: true
});

var theCanvas;



const win = new gui.QMainWindow();
win.resize(612 * 2, 792 * 2);

const scrollArea = new gui.QScrollArea();
win.setCentralWidget(scrollArea);

win.show();
global.win = win;

loadingTask.promise.then(pdfDoc => {
    console.log("Loaded document.");
    return pdfDoc.getPage(1);
}).then(page => {

    console.log("Loaded page");
    const viewport = page.getViewport({ scale: 2 });
    theCanvas = Canvas.createCanvas(viewport.width, viewport.height);

    return page.render({
        canvasContext: theCanvas.getContext("2d"),
        viewport,
    }).promise

}).then(() => {
    console.log("Done rendering");

    const image = new gui.QPixmap();

    image.loadFromData(theCanvas.toBuffer(), "PNG");
    const label = new gui.QLabel();
    label.setPixmap(image);
    label.addEventListener(
        gui.WidgetEventTypes.MouseButtonPress,
        (evt) => processMouseClick("button press", evt)
    );
    label.addEventListener(
        gui.WidgetEventTypes.MouseButtonRelease,
        (evt) => processMouseClick("button release", evt)
    );
    label.addEventListener(
        gui.WidgetEventTypes.MouseButtonDblClick,
        (evt) => processMouseClick("double click", evt)
    );
    label.addEventListener(
        gui.WidgetEventTypes.Move,
        (evt) => processMouseClick("move", evt)
    );
    scrollArea.setWidget(label);

}).catch(reason => console.log(reason));

function processMouseClick(type, evt) {
    const mouseEvt = new gui.QMouseEvent(evt);
    console.log(type + " (" + mouseEvt.x() + ", " + mouseEvt.y() + ")");
}


