const Canvas = require("canvas");
const fs = require("fs");
const pdfjs = require("pdfjs-dist/es5/build/pdf.js");

const formgui = require("./formgui.js");
const boxcalc = require("./boxcalc.js");



const data = new Uint8Array(fs.readFileSync("f1040.pdf"));

const loadingTask = pdfjs.getDocument({
    data,
    cMapUrl: "node_modules/pdfjs-dist/cmaps/",
    cMapPacked: true
});

var theCanvas;

var thePdfDoc;

let resolution = 2;

formgui.setBoxBounds(72 * resolution * 3, 72 * resolution / 2);


loadingTask.promise.then(pdfDoc => {
    console.log("Loaded document.");
    thePdfDoc = pdfDoc;
    formgui.setNumPages(pdfDoc.numPages);
})

async function selectPage(page) {
    if (thePdfDoc === undefined) { return; }
    console.log("Loading page " + page);
    const pageData = await thePdfDoc.getPage(page);
    console.log("Loaded page " + page);
    const viewport = pageData.getViewport({ scale: resolution });
    theCanvas = Canvas.createCanvas(viewport.width, viewport.height);

    await pageData.render({
        canvasContext: theCanvas.getContext("2d"),
        viewport,
    }).promise
    console.log("Done rendering");
    boxcalc.setCanvasContext(theCanvas.getContext("2d"));
    formgui.setPdfPage(theCanvas.toBuffer());
}

async function removeLineBox(text) {
    console.log("Removing line box " + text);
}

function computeBoxAtPoint(text, x, y) {
    var points = boxcalc.computeBoxAtPoint(x, y);
    formgui.addLineBox(text, ...points);
}

formgui.setEventHandlers({
    selectPage,
    removeLineBox,
    computeBoxAtPoint,
});


