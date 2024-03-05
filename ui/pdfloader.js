const Canvas = require("canvas");
const fs = require("fs");
const fsPromises = require("fs/promises");
const pdfjs = require("pdfjs-dist/legacy/build/pdf.js");

let pdfDoc = undefined;
let theCanvas = undefined;

async function loadPdf(filename) {
    console.log("Received command for file " + filename);
    const file = await fsPromises.readFile(filename);
    console.log("Read file");
    const data = new Uint8Array(file);
    pdfDoc = await pdfjs.getDocument({
        data,
        cMapUrl: "node_modules/pdfjs-dist/cmaps/",
        cMapPacked: true,
    }).promise;
    console.log("Loaded document");
}

function numPages() {
    return pdfDoc.numPages;
}

async function selectPage(page, resolution) {
    if (pdfDoc === undefined) { return; }
    console.log("Loading page " + page);
    const pageData = await pdfDoc.getPage(page);
    console.log("Loaded page " + page);
    const viewport = pageData.getViewport({ scale: resolution });
    theCanvas = Canvas.createCanvas(viewport.width, viewport.height);

    await pageData.render({
        canvasContext: theCanvas.getContext("2d"),
        viewport,
    }).promise
    console.log("Done rendering");
    return theCanvas;
}

module.exports = {
    loadPdf,
    selectPage,
    numPages,
}
